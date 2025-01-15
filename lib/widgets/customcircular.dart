import 'package:flutter/material.dart';
import 'dart:math' as math;

class CustomCircularProgressIndicator extends StatefulWidget {
  final String imagePath;
  final double size;
  final Duration duration;
  final bool isLoading;

  const CustomCircularProgressIndicator({super.key, 
    required this.imagePath,
    this.size = 80.0,
    this.duration = const Duration(seconds: 2),
    this.isLoading = true,
  });

  @override
  _CustomCircularProgressIndicatorState createState() => _CustomCircularProgressIndicatorState();
}

class _CustomCircularProgressIndicatorState extends State<CustomCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CustomCircularProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLoading
        ? AnimatedBuilder(
            animation: _controller,
            child: Image.asset(
              widget.imagePath,
              width: widget.size,
              height: widget.size,
            ),
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2.0 * math.pi,
                child: child,
              );
            },
          )
        : Image.asset(
            widget.imagePath,
            width: widget.size,
            height: widget.size,
          );
  }
}