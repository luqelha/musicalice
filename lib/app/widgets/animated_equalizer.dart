import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedEqualizer extends StatefulWidget {
  final double size;
  final Color color;
  final bool isAnimating;

  const AnimatedEqualizer({
    super.key,
    this.size = 20,
    this.color = const Color(0xFF1DB954),
    this.isAnimating = true,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    if (widget.isAnimating) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final values = List.generate(
            3,
            (i) => (math.sin((_controller.value * 2 * math.pi) + i) + 1) / 2,
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: values.map((v) {
              return Container(
                width: widget.size / 6,
                height: widget.size * (0.3 + v * 0.7),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
