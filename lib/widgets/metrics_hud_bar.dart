import 'package:flutter/material.dart';
import '../models/detection_models.dart';

class MetricsHudBar extends StatelessWidget {
  final ShelfMetrics? metrics;
  final bool isLiveActive;
  final bool isProcessing;

  const MetricsHudBar({
    super.key,
    required this.metrics,
    this.isLiveActive = true,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final shelfCount = m?.shelfCount ?? 0;
    final productCount = m?.productCount ?? 0;
    final emptyCount = m?.emptyCount ?? 0;
    final fullness = m?.stockFullnessPercent ?? 0.0;
    final latency = m?.inferenceTimeMs ?? 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC111827), // Dark translucent slate
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Live status indicator
              _buildLivePill(),
              const Spacer(),
              // Inference latency
              if (latency > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.amber[400], size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${latency.toStringAsFixed(0)} ms',
                        style: TextStyle(
                          color: Colors.amber[300],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                label: 'Shelves',
                value: '$shelfCount',
                color: const Color(0xFF00E676),
                icon: Icons.table_rows_rounded,
              ),
              _buildDivider(),
              _buildMetricItem(
                label: 'Products',
                value: '$productCount',
                color: const Color(0xFF00E5FF),
                icon: Icons.inventory_2_rounded,
              ),
              _buildDivider(),
              _buildMetricItem(
                label: 'Empty Slots',
                value: '$emptyCount',
                color: const Color(0xFFFF1744),
                icon: Icons.remove_shopping_cart_rounded,
              ),
              _buildDivider(),
              _buildMetricItem(
                label: 'Fullness',
                value: '${fullness.toStringAsFixed(0)}%',
                color: fullness >= 85
                    ? const Color(0xFF00E676)
                    : (fullness >= 60 ? Colors.amber : Colors.deepOrange),
                icon: Icons.donut_large_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLiveActive
            ? Colors.redAccent.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLiveActive ? Colors.redAccent : Colors.grey,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLiveActive ? Colors.redAccent : Colors.grey,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isLiveActive ? (isProcessing ? 'SCANNING...' : 'LIVE FEED') : 'PAUSED',
            style: TextStyle(
              color: isLiveActive ? Colors.white : Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withOpacity(0.12),
    );
  }
}
