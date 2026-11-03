import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';

/// Widget dựng biểu đồ động cho IELTS Writing Task 1
/// Hỗ trợ 3 chế độ:
/// 1. Ảnh đề thi từ Supabase Storage kèm thao tác chạm 2 ngón phóng to/thu nhỏ (InteractiveViewer).
/// 2. Biểu đồ cột tự động (Grouped Bar Chart) chia vạch, có nhãn số liệu và bảng chú thích.
/// 3. Biểu đồ đường tự động (Line Graph) vẽ qua CustomPainter mượt mà.
/// 4. Chế độ chuyển đổi Tab "Biểu đồ" <-> "Bảng số liệu (Data Table)" giúp học viên tra cứu nhanh số liệu.
class DynamicIeltsChartWidget extends StatefulWidget {
  final ChartDataModel chartData;

  const DynamicIeltsChartWidget({
    super.key,
    required this.chartData,
  });

  @override
  State<DynamicIeltsChartWidget> createState() => _DynamicIeltsChartWidgetState();
}

class _DynamicIeltsChartWidgetState extends State<DynamicIeltsChartWidget> {
  // 0: Chế độ Biểu đồ đồ họa, 1: Chế độ Bảng số liệu chi tiết
  int _viewMode = 0;

  @override
  Widget build(BuildContext context) {
    final chart = widget.chartData;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Biểu đồ & Nút chuyển Tab ──
          _buildHeader(context, chart),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Nội dung Biểu đồ / Bảng số liệu ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: chart.isImage
                ? _buildImageViewer(chart.imageUrl!)
                : (_viewMode == 0 ? _buildGraphicChart(chart) : _buildDataTable(chart)),
          ),

          // ── Bảng chú thích màu sắc (Legend) khi ở chế độ số liệu ──
          if (!chart.isImage && chart.series.isNotEmpty && _viewMode == 0)
            _buildLegend(chart),
        ],
      ),
    );
  }

  /// Header chứa Tiêu đề biểu đồ và nút chuyển Chế độ Biểu đồ / Bảng số liệu
  Widget _buildHeader(BuildContext context, ChartDataModel chart) {
    final title = chart.title ?? (chart.isImage ? 'Ảnh Đề Thi Task 1' : 'Biểu Đồ Số Liệu Task 1');
    final unit = chart.unit ?? '%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              chart.isImage
                  ? Icons.image_rounded
                  : (chart.isBarChart ? Icons.bar_chart_rounded : Icons.show_chart_rounded),
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!chart.isImage)
                  Text(
                    'Đơn vị đo: $unit',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          // Nút chuyển đổi Biểu đồ <-> Bảng số liệu (nếu là dạng dữ liệu số)
          if (!chart.isImage) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleTab(
                    icon: Icons.bar_chart_rounded,
                    label: 'Đồ thị',
                    isSelected: _viewMode == 0,
                    onTap: () => setState(() => _viewMode = 0),
                  ),
                  _buildToggleTab(
                    icon: Icons.table_chart_rounded,
                    label: 'Bảng số',
                    isSelected: _viewMode == 1,
                    onTap: () => setState(() => _viewMode = 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.navy : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. CHẾ ĐỘ ẢNH TỪ SUPABASE STORAGE (PINCH-TO-ZOOM)
  // ─────────────────────────────────────────────────────────────

  Widget _buildImageViewer(String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Gợi ý thao tác phóng to
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pinch_rounded, color: Color(0xFF2563EB), size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dùng 2 ngón tay chạm & kéo để phóng to / thu nhỏ biểu đồ',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // Khung ảnh có zoom
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFFF8FAFC),
            constraints: const BoxConstraints(maxHeight: 280),
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              clipBehavior: Clip.none,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Đang tải biểu đồ từ Supabase Cloud...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 180,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded, color: Colors.redAccent, size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'Không thể tải ảnh biểu đồ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        url,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. CHẾ ĐỘ BIỂU ĐỒ ĐỒ HỌA (BAR CHART & LINE GRAPH)
  // ─────────────────────────────────────────────────────────────

  Widget _buildGraphicChart(ChartDataModel chart) {
    if (chart.categories.isEmpty || chart.series.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: const Text('Không có dữ liệu số liệu cho biểu đồ này', style: TextStyle(color: Colors.grey)),
      );
    }

    if (chart.isLineGraph) {
      return _buildLineGraph(chart);
    }

    return _buildBarChart(chart);
  }

  /// Xây dựng Biểu đồ Cột (Grouped Bar Chart)
  Widget _buildBarChart(ChartDataModel chart) {
    // Tìm giá trị lớn nhất trong toàn bộ dữ liệu
    double maxVal = 0.0;
    for (final s in chart.series) {
      for (final v in s.values) {
        if (v > maxVal) maxVal = v;
      }
    }
    if (maxVal <= 0) maxVal = 100.0;
    // Làm tròn lên mốc chẵn đẹp
    final double yCeil = (maxVal <= 100 && (chart.unit == '%' || chart.unit == null))
        ? 100.0
        : (math.max((maxVal * 1.15).ceilToDouble(), 10.0));

    const double chartHeight = 190.0;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Trục tung Y (Số mốc)
              SizedBox(
                width: 38,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${yCeil.toInt()}${chart.unit ?? ""}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text('${(yCeil * 0.75).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(yCeil * 0.5).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(yCeil * 0.25).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const Text('0', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Vùng vẽ các nhóm cột và đường lưới ngang
              Expanded(
                child: Stack(
                  children: [
                    // Các đường lưới ngang (Grid Lines)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        5,
                        (index) => Container(
                          height: 1,
                          color: const Color(0xFFF1F5F9),
                        ),
                      ),
                    ),

                    // Nhóm cột theo từng category (Mốc thời gian)
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chart.categories.asMap().entries.map((catEntry) {
                          final catIndex = catEntry.key;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: chart.series.map((s) {
                                  final double val = (catIndex < s.values.length) ? s.values[catIndex] : 0.0;
                                  final double barHeight = (val / yCeil) * (chartHeight - 24);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Nhãn giá trị trên đầu cột
                                        Text(
                                          val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: s.color,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Cột biểu đồ
                                        Container(
                                          width: 14,
                                          height: math.max(barHeight, 3.0),
                                          decoration: BoxDecoration(
                                            color: s.color,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: s.color.withValues(alpha: 0.25),
                                                blurRadius: 3,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Nhãn trục hoành X (Categories)
        Row(
          children: [
            const SizedBox(width: 46), // Khoảng trống khớp trục Y
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: chart.categories.map((cat) {
                  return Expanded(
                    child: Text(
                      cat,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Xây dựng Biểu đồ Đường (Line Graph với CustomPainter)
  Widget _buildLineGraph(ChartDataModel chart) {
    double maxVal = 0.0;
    for (final s in chart.series) {
      for (final v in s.values) {
        if (v > maxVal) maxVal = v;
      }
    }
    if (maxVal <= 0) maxVal = 100.0;
    final double yCeil = math.max((maxVal * 1.15).ceilToDouble(), 10.0);

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trục tung Y
              SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${yCeil.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Text('${(yCeil * 0.75).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(yCeil * 0.5).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(yCeil * 0.25).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const Text('0', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Canvas vẽ đường Line Graph
              Expanded(
                child: CustomPaint(
                  painter: _LineGraphPainter(
                    categories: chart.categories,
                    series: chart.series,
                    yMax: yCeil,
                    unit: chart.unit ?? '',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Nhãn trục hoành X
        Row(
          children: [
            const SizedBox(width: 50),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: chart.categories.map((cat) {
                  return Text(
                    cat,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. CHẾ ĐỘ BẢNG SỐ LIỆU (DATA TABLE VIEW)
  // ─────────────────────────────────────────────────────────────

  Widget _buildDataTable(ChartDataModel chart) {
    final unit = chart.unit ?? '';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columnSpacing: 22,
          horizontalMargin: 12,
          headingRowHeight: 40,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 42,
          columns: [
            const DataColumn(
              label: Text(
                'Nhóm / Tiêu chí',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 12),
              ),
            ),
            ...chart.categories.map(
              (cat) => DataColumn(
                label: Text(
                  cat,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 12),
                ),
              ),
            ),
          ],
          rows: chart.series.map((s) {
            return DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.navy),
                      ),
                    ],
                  ),
                ),
                ...chart.categories.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final val = (idx < s.values.length) ? s.values[idx] : 0.0;
                  final valStr = val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
                  return DataCell(
                    Text(
                      '$valStr$unit',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Bảng chú thích (Legend) ──
  Widget _buildLegend(ChartDataModel chart) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: chart.series.map((s) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: s.color.withValues(alpha: 0.3), blurRadius: 2),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                s.name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// CustomPainter vẽ biểu đồ đường Line Graph
class _LineGraphPainter extends CustomPainter {
  final List<String> categories;
  final List<ChartSeriesModel> series;
  final double yMax;
  final String unit;

  _LineGraphPainter({
    required this.categories,
    required this.series,
    required this.yMax,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (categories.isEmpty || yMax <= 0) return;

    // 1. Vẽ 5 đường lưới ngang
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 5; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Tính tọa độ X cho từng category
    final double stepX = categories.length > 1
        ? size.width / (categories.length - 1)
        : size.width / 2;

    // 3. Vẽ từng chuỗi đường
    for (final s in series) {
      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final pointPaint = Paint()
        ..color = s.color
        ..style = PaintingStyle.fill;

      final whiteRingPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final path = Path();
      final List<Offset> points = [];

      for (int i = 0; i < categories.length; i++) {
        final double x = categories.length > 1 ? i * stepX : size.width / 2;
        final double val = (i < s.values.length) ? s.values[i] : 0.0;
        final double ratio = (val / yMax).clamp(0.0, 1.0);
        final double y = size.height - (ratio * size.height);

        points.add(Offset(x, y));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Vẽ đường nối
      canvas.drawPath(path, linePaint);

      // Vẽ các chấm tròn điểm số liệu
      for (final pt in points) {
        canvas.drawCircle(pt, 5.0, whiteRingPaint);
        canvas.drawCircle(pt, 3.5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineGraphPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.yMax != yMax;
  }
}
