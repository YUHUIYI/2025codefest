import 'package:flutter/material.dart';
import 'package:town_pass/util/tp_colors.dart';
import 'package:town_pass/util/tp_constant.dart';
import 'package:town_pass/util/tp_text_styles.dart';

/// 使用指引步骤
class SvUsageGuideStep {
  final String title;
  final String description;
  final GlobalKey targetKey;
  final Offset? targetOffset;
  final Size? targetSize;

  SvUsageGuideStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.targetOffset,
    this.targetSize,
  });
}

/// 使用指引组件
class SvUsageGuide extends StatefulWidget {
  final List<SvUsageGuideStep> steps;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const SvUsageGuide({
    super.key,
    required this.steps,
    this.onComplete,
    this.onSkip,
  });

  @override
  State<SvUsageGuide> createState() => _SvUsageGuideState();
}

class _SvUsageGuideState extends State<SvUsageGuide> {
  int _currentStep = 0;
  final Map<int, Rect> _targetRects = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRects();
    });
  }

  @override
  void didUpdateWidget(SvUsageGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps != widget.steps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTargetRects();
      });
    }
  }

  void _updateTargetRects() {
    // 获取 AppBar 和状态栏的高度
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top;
    final appBarHeight = kTPToolbarHeight;
    final totalOffset = appBarHeight + statusBarHeight;

    // 获取 Stack 的位置（相对于屏幕）
    final stackContext = context.findAncestorRenderObjectOfType<RenderBox>();
    Offset? stackOffset;
    if (stackContext != null && stackContext.attached) {
      try {
        stackOffset = stackContext.localToGlobal(Offset.zero);
      } catch (e) {
        print('Failed to get stack position: $e');
      }
    }

    for (int i = 0; i < widget.steps.length; i++) {
      final step = widget.steps[i];
      final context = step.targetKey.currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.attached) {
          try {
            // localToGlobal 返回的是相对于整个屏幕的坐标
            final globalOffset = renderBox.localToGlobal(Offset.zero);
            final size = renderBox.size;
            
            // 如果获取到了 Stack 的位置，使用相对位置
            // 否则使用绝对位置减去 AppBar 和状态栏高度
            final yPosition = stackOffset != null
                ? globalOffset.dy - stackOffset.dy
                : globalOffset.dy - totalOffset;
            
            _targetRects[i] = Rect.fromLTWH(
              globalOffset.dx,
              yPosition,
              size.width,
              size.height,
            );
          } catch (e) {
            // 如果获取位置失败，跳过这个步骤
            print('Failed to get position for step $i: $e');
          }
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTargetRects();
      });
    } else {
      _complete();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTargetRects();
      });
    }
  }

  void _complete() {
    widget.onComplete?.call();
  }

  void _skip() {
    widget.onSkip?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentStep = widget.steps[_currentStep];
    final targetRect = _targetRects[_currentStep];

    return Stack(
      children: [
        // 遮罩层
        _buildOverlay(targetRect),
        // 高亮区域
        if (targetRect != null) _buildHighlight(targetRect),
        // 说明卡片
        if (targetRect != null) _buildTooltip(targetRect, currentStep),
      ],
    );
  }

  Widget _buildOverlay(Rect? targetRect) {
    return GestureDetector(
      onTap: _nextStep,
      child: CustomPaint(
        painter: OverlayPainter(targetRect),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildHighlight(Rect targetRect) {
    // 与遮罩裁剪区域对齐，使用相同的边距
    return Positioned(
      left: targetRect.left - 12,
      top: targetRect.top - 12,
      child: Container(
        width: targetRect.width + 24,
        height: targetRect.height + 24,
        decoration: BoxDecoration(
          color: Colors.transparent, // 明确设置为透明
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TPColors.primary500,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: TPColors.primary500.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(Rect targetRect, SvUsageGuideStep step) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 判断说明卡片应该显示在高亮区域的上方还是下方
    // 对于后面的步骤（步骤2、3、4），需要往上移更多，避免遮挡高亮框
    final showAbove = targetRect.center.dy > screenHeight / 2;
    final isLaterStep = _currentStep >= 1; // 步骤2、3、4（索引从0开始）
    final verticalOffset = isLaterStep && showAbove ? 240 : 200; // 后面的步骤往上移更多
    
    final tooltipTop = showAbove
        ? targetRect.top - verticalOffset  // 根据步骤调整间距
        : targetRect.bottom + 30;  // 下方显示时保持间距

    return Positioned(
      left: 16,
      right: 16,
      top: tooltipTop.clamp(0.0, screenHeight - 200),
      child: Container(
        decoration: BoxDecoration(
          color: TPColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: TPColors.grayscale900.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和步骤指示器
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: TPTextStyles.h2SemiBold.copyWith(
                      color: TPColors.grayscale950,
                    ),
                  ),
                ),
                Text(
                  '${_currentStep + 1} / ${widget.steps.length}',
                  style: TPTextStyles.bodyRegular.copyWith(
                    color: TPColors.grayscale600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 说明文字
            Text(
              step.description,
              style: TPTextStyles.bodyRegular.copyWith(
                color: TPColors.grayscale700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // 按钮区域
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    '跳过',
                    style: TPTextStyles.bodySemiBold.copyWith(
                      color: TPColors.grayscale600,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: _previousStep,
                        child: Text(
                          '上一步',
                          style: TPTextStyles.bodySemiBold.copyWith(
                            color: TPColors.primary500,
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TPColors.primary500,
                        foregroundColor: TPColors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _currentStep < widget.steps.length - 1
                            ? '下一步'
                            : '完成',
                        style: TPTextStyles.bodySemiBold.copyWith(
                          color: TPColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 遮罩绘制器
class OverlayPainter extends CustomPainter {
  final Rect? targetRect;

  OverlayPainter(this.targetRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TPColors.grayscale900.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // 如果有目标区域，先绘制遮罩，然后裁剪出高亮区域
    if (targetRect != null) {
      // 创建整个屏幕的路径
      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      
      // 创建高亮区域的路径（带圆角，增加一些边距确保完全不被遮罩覆盖）
      final highlightPath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              targetRect!.left - 12,  // 增加边距
              targetRect!.top - 12,   // 增加边距
              targetRect!.width + 24, // 增加边距
              targetRect!.height + 24, // 增加边距
            ),
            const Radius.circular(12),
          ),
        );
      
      // 使用 PathOperation.difference 来裁剪出高亮区域
      final finalPath = Path.combine(
        PathOperation.difference,
        path,
        highlightPath,
      );

      canvas.drawPath(finalPath, paint);
    } else {
      // 如果没有目标区域，绘制整个屏幕的遮罩
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(OverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

