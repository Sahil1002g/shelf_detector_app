import 'package:flutter/material.dart';
import '../models/detection_models.dart';

class BoundingBoxOverlay extends StatelessWidget {
  final DetectionResult? result;
  final Size previewSize;
  final BoxFit fit;
  final bool showShelves;
  final bool showProducts;
  final bool showEmptySpaces;
  final bool showLabels;
  final Function(dynamic)? onItemTapped;

  const BoundingBoxOverlay({
    super.key,
    required this.result,
    required this.previewSize,
    this.fit = BoxFit.cover,
    this.showShelves = true,
    this.showProducts = true,
    this.showEmptySpaces = true,
    this.showLabels = true,
    this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null) return const SizedBox.shrink();

    return CustomPaint(
      size: Size.infinite,
      painter: ShelfBoundingBoxPainter(
        result: result!,
        showShelves: showShelves,
        showProducts: showProducts,
        showEmptySpaces: showEmptySpaces,
        showLabels: showLabels,
      ),
    );
  }
}

class ShelfBoundingBoxPainter extends CustomPainter {
  final DetectionResult result;
  final bool showShelves;
  final bool showProducts;
  final bool showEmptySpaces;
  final bool showLabels;

  ShelfBoundingBoxPainter({
    required this.result,
    required this.showShelves,
    required this.showProducts,
    required this.showEmptySpaces,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Shelf Rows (Emerald Green)
    if (showShelves) {
      for (final shelf in result.shelves) {
        _drawShelfRow(canvas, size, shelf);
      }
    }

    // 2. Draw Products (Electric Cyan)
    if (showProducts) {
      for (final prod in result.products) {
        _drawProduct(canvas, size, prod);
      }
    }

    // 3. Draw Empty Spaces (Crimson Red / Amber)
    if (showEmptySpaces) {
      for (final empty in result.emptySpaces) {
        _drawEmptySpace(canvas, size, empty);
      }
    }
  }

  void _drawShelfRow(Canvas canvas, Size size, ShelfDetection shelf) {
    final box = shelf.box;
    final rect = Rect.fromLTRB(
      box.xmin * size.width,
      box.ymin * size.height,
      box.xmax * size.width,
      box.ymax * size.height,
    );

    // Shelf Fill
    final fillPaint = Paint()
      ..color = const Color(0x1800E676)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), fillPaint);

    // Shelf Border
    final borderPaint = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    if (showLabels) {
      final labelText = '${shelf.label}  ${(shelf.confidence * 100).toStringAsFixed(0)}%';
      _drawBadge(
        canvas: canvas,
        text: labelText,
        x: rect.left + 4,
        y: rect.top - 22 > 0 ? rect.top - 22 : rect.top + 4,
        backgroundColor: const Color(0xDD00E676),
        textColor: Colors.black,
        icon: Icons.layers_outlined,
      );
    }
  }

  void _drawProduct(Canvas canvas, Size size, ProductDetection prod) {
    final box = prod.box;
    final rect = Rect.fromLTRB(
      box.xmin * size.width,
      box.ymin * size.height,
      box.xmax * size.width,
      box.ymax * size.height,
    );

    // Product Fill (subtle)
    final fillPaint = Paint()
      ..color = const Color(0x1500E5FF)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Product Border
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRect(rect, borderPaint);

    // Corner accents
    _drawCornerAccents(canvas, rect, const Color(0xFF00E5FF));

    if (showLabels) {
      final labelText = 'P ${(prod.confidence * 100).toStringAsFixed(0)}%';
      _drawBadge(
        canvas: canvas,
        text: labelText,
        x: rect.left,
        y: rect.top - 18 > 0 ? rect.top - 18 : rect.top,
        backgroundColor: const Color(0xDD00E5FF),
        textColor: Colors.black,
        fontSize: 10,
      );
    }
  }

  void _drawEmptySpace(Canvas canvas, Size size, ProductDetection empty) {
    final box = empty.box;
    final rect = Rect.fromLTRB(
      box.xmin * size.width,
      box.ymin * size.height,
      box.xmax * size.width,
      box.ymax * size.height,
    );

    // Warning Red Fill
    final fillPaint = Paint()
      ..color = const Color(0x28FF1744)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // Warning Red Border
    final borderPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);

    // Crossed lines or hazard mark
    final crossPaint = Paint()
      ..color = const Color(0x66FF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(rect.topLeft, rect.bottomRight, crossPaint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, crossPaint);

    if (showLabels) {
      final labelText = 'EMPTY ${(empty.confidence * 100).toStringAsFixed(0)}%';
      _drawBadge(
        canvas: canvas,
        text: labelText,
        x: rect.left,
        y: rect.top - 18 > 0 ? rect.top - 18 : rect.top,
        backgroundColor: const Color(0xEEFF1744),
        textColor: Colors.white,
        fontSize: 10,
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;

    const len = 6.0;
    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, len), paint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight - const Offset(len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + const Offset(0, len), paint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(len, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, len), paint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(len, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight - const Offset(0, len), paint);
  }

  void _drawBadge({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required Color backgroundColor,
    required Color textColor,
    double fontSize = 11,
    IconData? icon,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 5.0;
    const paddingV = 2.5;
    final badgeWidth = textPainter.width + (paddingH * 2);
    final badgeHeight = textPainter.height + (paddingV * 2);

    final bgRect = Rect.fromLTWH(x, y, badgeWidth, badgeHeight);
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), bgPaint);
    textPainter.paint(canvas, Offset(x + paddingH, y + paddingV));
  }

  @override
  bool shouldRepaint(covariant ShelfBoundingBoxPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.showShelves != showShelves ||
        oldDelegate.showProducts != showProducts ||
        oldDelegate.showEmptySpaces != showEmptySpaces ||
        oldDelegate.showLabels != showLabels;
  }
}
