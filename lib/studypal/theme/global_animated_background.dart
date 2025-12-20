import 'package:flutter/material.dart';
import 'app_theme.dart';

/// A single animated gradient background intended to wrap the entire app.
/// Use this at the top of the widget tree so individual pages don't create
/// their own animated backgrounds.
class GlobalAnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;
  final bool animate;

  const GlobalAnimatedBackground({
    super.key,
    required this.child,
    this.colors,
    this.animate = true,
  });

  @override
  State<GlobalAnimatedBackground> createState() =>
      _GlobalAnimatedBackgroundState();
}

class _GlobalAnimatedBackgroundState extends State<GlobalAnimatedBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<Alignment>? _topAlignmentAnimation;
  Animation<Alignment>? _bottomAlignmentAnimation;

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(_animationController!);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
    ]).animate(_animationController!);
  }

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _initAnimations();
    }
  }

  @override
  void didUpdateWidget(covariant GlobalAnimatedBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && _animationController == null) {
      _initAnimations();
    } else if (!widget.animate && _animationController != null) {
      _animationController?.dispose();
      _animationController = null;
      _topAlignmentAnimation = null;
      _bottomAlignmentAnimation = null;
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? AppTheme.primaryGradient;

    if (!widget.animate || _animationController == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _animationController!,
      child: widget.child,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _topAlignmentAnimation!.value,
              end: _bottomAlignmentAnimation!.value,
              colors: colors,
            ),
          ),
          child: child,
        );
      },
    );
  }
}
