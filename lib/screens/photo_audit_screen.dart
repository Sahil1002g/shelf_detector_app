import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/detection_models.dart';
import '../services/ai_detection_service.dart';
import '../widgets/bounding_box_overlay.dart';

class PhotoAuditScreen extends StatefulWidget {
  final File? imageFile;
  final Uint8List? imageBytes;
  final String? assetPath;
  final DetectionResult initialResult;

  const PhotoAuditScreen({
    super.key,
    this.imageFile,
    this.imageBytes,
    this.assetPath,
    required this.initialResult,
  });

  @override
  State<PhotoAuditScreen> createState() => _PhotoAuditScreenState();
}

class _PhotoAuditScreenState extends State<PhotoAuditScreen> with SingleTickerProviderStateMixin {
  late DetectionResult _result;
  bool _isProcessing = false;
  bool _showShelves = true;
  bool _showProducts = true;
  bool _showEmptySpaces = true;
  bool _showLabels = true;
  double _shelfConf = 0.25;
  double _productConf = 0.25;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _result = widget.initialResult;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reanalyze() async {
    setState(() => _isProcessing = true);
    try {
      DetectionResult newRes;
      if (widget.imageFile != null) {
        newRes = await AiDetectionService().detectFromFile(
          widget.imageFile!,
          shelfConf: _shelfConf,
          productConf: _productConf,
        );
      } else if (widget.imageBytes != null) {
        newRes = await AiDetectionService().detectFromBytes(
          widget.imageBytes!,
          shelfConf: _shelfConf,
          productConf: _productConf,
        );
      } else if (widget.assetPath != null) {
        newRes = await AiDetectionService().detectFromAsset(
          widget.assetPath!,
          shelfConf: _shelfConf,
          productConf: _productConf,
        );
      } else {
        newRes = _result;
      }

      if (mounted) {
        setState(() {
          _result = newRes;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Re-analysis failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _result.metrics;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Shelf & Product Audit',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-analyze',
            onPressed: _isProcessing ? null : _reanalyze,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter thresholds',
            onPressed: _showThresholdFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Metrics Header
          _buildMetricsBanner(m),

          // Layer Toggle Chips
          _buildLayerChips(),

          // Interactive Photo + Bounding Box Canvas
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _result.imageWidth / _result.imageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImageWidget(),
                          BoundingBoxOverlay(
                            result: _result,
                            previewSize: Size(_result.imageWidth.toDouble(), _result.imageHeight.toDouble()),
                            showShelves: _showShelves,
                            showProducts: _showProducts,
                            showEmptySpaces: _showEmptySpaces,
                            showLabels: _showLabels,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF00E676)),
                          SizedBox(height: 12),
                          Text(
                            'Processing AI models...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Detections List & Audit Details
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF00E676),
                    labelColor: const Color(0xFF00E676),
                    unselectedLabelColor: Colors.white60,
                    tabs: [
                      Tab(text: 'Products (${_result.products.length})'),
                      Tab(text: 'Shelves (${_result.shelves.length})'),
                      Tab(text: 'Empty (${_result.emptySpaces.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProductsList(),
                        _buildShelvesList(),
                        _buildEmptyList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF0F172A),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                label: const Text('Retake', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, color: Colors.black),
                label: const Text('Accept Audit', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Audit report saved successfully!'),
                      backgroundColor: Color(0xFF00E676),
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (widget.imageFile != null) {
      return Image.file(widget.imageFile!, fit: BoxFit.contain);
    } else if (widget.imageBytes != null) {
      return Image.memory(widget.imageBytes!, fit: BoxFit.contain);
    } else if (widget.assetPath != null) {
      return Image.asset(widget.assetPath!, fit: BoxFit.contain);
    }
    return Container(color: Colors.grey[900]);
  }

  Widget _buildMetricsBanner(ShelfMetrics m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPill('Shelves', '${m.shelfCount}', const Color(0xFF00E676)),
          _buildPill('Products', '${m.productCount}', const Color(0xFF00E5FF)),
          _buildPill('Empty', '${m.emptyCount}', const Color(0xFFFF1744)),
          _buildPill('Fullness', '${m.stockFullnessPercent.toStringAsFixed(0)}%', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildPill(String title, String val, Color c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(val, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildLayerChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF0F172A),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('Shelves'),
              selected: _showShelves,
              selectedColor: const Color(0xFF00E676).withOpacity(0.3),
              checkmarkColor: const Color(0xFF00E676),
              labelStyle: TextStyle(color: _showShelves ? const Color(0xFF00E676) : Colors.white60, fontSize: 12),
              onSelected: (val) => setState(() => _showShelves = val),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Products'),
              selected: _showProducts,
              selectedColor: const Color(0xFF00E5FF).withOpacity(0.3),
              checkmarkColor: const Color(0xFF00E5FF),
              labelStyle: TextStyle(color: _showProducts ? const Color(0xFF00E5FF) : Colors.white60, fontSize: 12),
              onSelected: (val) => setState(() => _showProducts = val),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Empty Slots'),
              selected: _showEmptySpaces,
              selectedColor: const Color(0xFFFF1744).withOpacity(0.3),
              checkmarkColor: const Color(0xFFFF1744),
              labelStyle: TextStyle(color: _showEmptySpaces ? const Color(0xFFFF1744) : Colors.white60, fontSize: 12),
              onSelected: (val) => setState(() => _showEmptySpaces = val),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Labels'),
              selected: _showLabels,
              selectedColor: Colors.white24,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(color: _showLabels ? Colors.white : Colors.white60, fontSize: 12),
              onSelected: (val) => setState(() => _showLabels = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (_result.products.isEmpty) {
      return const Center(child: Text('No products detected', style: TextStyle(color: Colors.white38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _result.products.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final p = _result.products[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF00E5FF), size: 18),
          ),
          title: Text(
            'Product #${p.id}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            'Row: ${p.shelfRow != null ? "#${p.shelfRow}" : "General"} • Box: [${p.boxPixels.map((e) => e.toInt()).join(", ")}]',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(p.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShelvesList() {
    if (_result.shelves.isEmpty) {
      return const Center(child: Text('No shelf rows detected', style: TextStyle(color: Colors.white38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _result.shelves.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final s = _result.shelves[index];
        final prodsOnShelf = _result.products.where((p) => p.shelfRow == s.id).length;
        final emptyOnShelf = _result.emptySpaces.where((e) => e.shelfRow == s.id).length;

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.table_rows_rounded, color: Color(0xFF00E676), size: 18),
          ),
          title: Text(
            s.label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '$prodsOnShelf products • $emptyOnShelf empty slots',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(s.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyList() {
    if (_result.emptySpaces.isEmpty) {
      return const Center(child: Text('No empty shelf spaces detected (Fully stocked!)', style: TextStyle(color: Colors.white38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _result.emptySpaces.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final e = _result.emptySpaces[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1744).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.remove_shopping_cart_rounded, color: Color(0xFFFF1744), size: 18),
          ),
          title: Text(
            'Empty Slot #${e.id}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            'Shelf Row: ${e.shelfRow != null ? "#${e.shelfRow}" : "General"} (Requires Restock)',
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1744).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${(e.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  void _showThresholdFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjust Detection Confidence',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('Shelf Threshold: ${(_shelfConf * 100).toInt()}%', style: const TextStyle(color: Color(0xFF00E676))),
                  Slider(
                    value: _shelfConf,
                    min: 0.10,
                    max: 0.90,
                    activeColor: const Color(0xFF00E676),
                    onChanged: (v) => setModalState(() => _shelfConf = v),
                  ),
                  Text('Product Threshold: ${(_productConf * 100).toInt()}%', style: const TextStyle(color: Color(0xFF00E5FF))),
                  Slider(
                    value: _productConf,
                    min: 0.10,
                    max: 0.90,
                    activeColor: const Color(0xFF00E5FF),
                    onChanged: (v) => setModalState(() => _productConf = v),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _reanalyze();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Re-run Models', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
