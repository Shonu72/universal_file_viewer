import 'package:flutter/material.dart';

/// A pure Flutter widget that displays a shimmering loading animation over a child widget.
class ShimmerWidget extends StatefulWidget {
  /// The child widget to apply the shimmer effect to.
  final Widget child;

  /// The base color of the shimmer gradient.
  final Color baseColor;

  /// The highlight color of the shimmer gradient.
  final Color highlightColor;

  /// The duration of one complete shimmer animation cycle.
  final Duration period;

  /// Creates a [ShimmerWidget].
  const ShimmerWidget({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    this.period = const Duration(milliseconds: 1500),
  });

  /// Creates a [ShimmerWidget] with [baseColor] and [highlightColor].
  const ShimmerWidget.fromColors({
    super.key,
    required this.baseColor,
    required this.highlightColor,
    required this.child,
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            final double value = _controller.value;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const <double>[0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
        bounds.width * (slidePercent * 2 - 1), 0, 0);
  }
}
