/// Represents a single bounding box normalized to [ymin, xmin, ymax, xmax] (0.0 to 1.0)
class BoundingBox {
  final double ymin;
  final double xmin;
  final double ymax;
  final double xmax;

  const BoundingBox({
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
  });

  factory BoundingBox.fromList(List<dynamic> list) {
    if (list.length >= 4) {
      return BoundingBox(
        ymin: (list[0] as num).toDouble(),
        xmin: (list[1] as num).toDouble(),
        ymax: (list[2] as num).toDouble(),
        xmax: (list[3] as num).toDouble(),
      );
    }
    return const BoundingBox(ymin: 0, xmin: 0, ymax: 0, xmax: 0);
  }

  double get width => (xmax - xmin).abs();
  double get height => (ymax - ymin).abs();
  double get centerX => (xmin + xmax) / 2.0;
  double get centerY => (ymin + ymax) / 2.0;
}

/// Shelf row detection from `segment_shelf_rows`
class ShelfDetection {
  final int id;
  final String label;
  final double confidence;
  final BoundingBox box;
  final List<double> boxPixels;

  ShelfDetection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.box,
    required this.boxPixels,
  });

  factory ShelfDetection.fromJson(Map<String, dynamic> json) {
    return ShelfDetection(
      id: json['id'] ?? 0,
      label: json['label'] ?? 'Shelf Row',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      box: BoundingBox.fromList(json['box'] ?? [0, 0, 0, 0]),
      boxPixels: (json['box_pixels'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
    );
  }
}

/// Product / Empty Space detection from `detect_product_empty_space`
class ProductDetection {
  final int id;
  final String label;
  final int classId;
  final double confidence;
  final BoundingBox box;
  final List<double> boxPixels;
  final int? shelfRow;

  ProductDetection({
    required this.id,
    required this.label,
    required this.classId,
    required this.confidence,
    required this.box,
    required this.boxPixels,
    this.shelfRow,
  });

  bool get isProduct => label.toLowerCase() == 'product';
  bool get isEmptySpace => !isProduct;

  factory ProductDetection.fromJson(Map<String, dynamic> json) {
    return ProductDetection(
      id: json['id'] ?? 0,
      label: json['label'] ?? 'product',
      classId: json['class_id'] ?? 1,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      box: BoundingBox.fromList(json['box'] ?? [0, 0, 0, 0]),
      boxPixels: (json['box_pixels'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      shelfRow: json['shelf_row'] as int?,
    );
  }
}

/// Detection summary metrics
class ShelfMetrics {
  final int shelfCount;
  final int productCount;
  final int emptyCount;
  final int totalSlots;
  final double stockFullnessPercent;
  final double inferenceTimeMs;
  final double shelfTimeMs;
  final double productTimeMs;

  ShelfMetrics({
    required this.shelfCount,
    required this.productCount,
    required this.emptyCount,
    required this.totalSlots,
    required this.stockFullnessPercent,
    required this.inferenceTimeMs,
    required this.shelfTimeMs,
    required this.productTimeMs,
  });

  factory ShelfMetrics.fromJson(Map<String, dynamic> json) {
    return ShelfMetrics(
      shelfCount: json['shelf_count'] ?? 0,
      productCount: json['product_count'] ?? 0,
      emptyCount: json['empty_count'] ?? 0,
      totalSlots: json['total_slots'] ?? 0,
      stockFullnessPercent:
          (json['stock_fullness_percent'] as num?)?.toDouble() ?? 0.0,
      inferenceTimeMs: (json['inference_time_ms'] as num?)?.toDouble() ?? 0.0,
      shelfTimeMs: (json['shelf_time_ms'] as num?)?.toDouble() ?? 0.0,
      productTimeMs: (json['product_time_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Complete combined detection result for an image or camera frame
class DetectionResult {
  final bool success;
  final int imageWidth;
  final int imageHeight;
  final List<ShelfDetection> shelves;
  final List<ProductDetection> products;
  final List<ProductDetection> emptySpaces;
  final ShelfMetrics metrics;

  DetectionResult({
    required this.success,
    required this.imageWidth,
    required this.imageHeight,
    required this.shelves,
    required this.products,
    required this.emptySpaces,
    required this.metrics,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final imageSize = json['image_size'] as Map<String, dynamic>? ?? {};
    final rawShelves = (json['shelves'] as List<dynamic>?) ?? [];
    final rawProducts = (json['products'] as List<dynamic>?) ?? [];
    final rawEmpty = (json['empty_spaces'] as List<dynamic>?) ?? [];

    return DetectionResult(
      success: json['success'] ?? true,
      imageWidth: imageSize['width'] ?? 640,
      imageHeight: imageSize['height'] ?? 640,
      shelves: rawShelves.map((e) => ShelfDetection.fromJson(e)).toList(),
      products: rawProducts.map((e) => ProductDetection.fromJson(e)).toList(),
      emptySpaces: rawEmpty.map((e) => ProductDetection.fromJson(e)).toList(),
      metrics: ShelfMetrics.fromJson(json['metrics'] ?? {}),
    );
  }

  factory DetectionResult.empty() {
    return DetectionResult(
      success: true,
      imageWidth: 640,
      imageHeight: 640,
      shelves: [],
      products: [],
      emptySpaces: [],
      metrics: ShelfMetrics(
        shelfCount: 0,
        productCount: 0,
        emptyCount: 0,
        totalSlots: 0,
        stockFullnessPercent: 0.0,
        inferenceTimeMs: 0.0,
        shelfTimeMs: 0.0,
        productTimeMs: 0.0,
      ),
    );
  }
}
