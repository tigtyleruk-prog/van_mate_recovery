import 'dart:math' as math;

import 'package:flutter/material.dart';

class VanMateStartupSplash extends StatefulWidget {
  const VanMateStartupSplash({super.key, required this.onAnimationFinished});

  final VoidCallback onAnimationFinished;

  @override
  State<VanMateStartupSplash> createState() => _VanMateStartupSplashState();
}

class _VanMateStartupSplashState extends State<VanMateStartupSplash>
    with TickerProviderStateMixin {
  late final AnimationController _logoEntranceController;
  late final AnimationController _textRevealController;
  late final Animation<double> _textRevealProgress;
  late final AnimationController _growthController;
  late final AnimationController _logoShimmerController;
  late final AnimationController _logoSparkleController;

  @override
  void initState() {
    super.initState();
    _logoEntranceController = AnimationController(vsync: this, value: 1);
    _textRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _textRevealProgress = CurvedAnimation(
      parent: _textRevealController,
      curve: const Interval(250 / 1200, 1),
    );
    _growthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 770),
    );
    _logoShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _logoSparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _playAnimation();
  }

  Future<void> _playAnimation() async {
    final textReveal = _textRevealController.forward();
    await textReveal;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _growthController.forward();
    await _logoShimmerController.forward();
    await _logoSparkleController.forward();
    if (mounted) {
      widget.onAnimationFinished();
    }
  }

  @override
  void dispose() {
    _logoEntranceController.dispose();
    _textRevealController.dispose();
    _growthController.dispose();
    _logoShimmerController.dispose();
    _logoSparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071224),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1930), Color(0xFF071224)],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: constraints.maxHeight * 0.27,
                  height: constraints.maxHeight * 0.31,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _growthController,
                      builder: (context, _) => Opacity(
                        opacity: 1 - _logoLockProgress,
                        child: CustomPaint(
                          painter: _GrowthLinePainter(
                            Curves.easeOutCubic.transform(
                              _growthController.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.28),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _logoEntranceController,
                      curve: Curves.easeOutCubic,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: Listenable.merge([
                                  _growthController,
                                ]),
                                builder: (context, _) => SizedBox(
                                  width: 78,
                                  height: 78,
                                  child: CustomPaint(
                                    painter: _BusinessMateLogoPainter(
                                      barProgress: _logoLockProgress,
                                      breath: 0,
                                      pulse: _logoLockProgress,
                                      strike: _growthController.value,
                                      shimmer: 0,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 36,
                                child: Center(
                                  child: _TextReveal(
                                    progress: _textRevealProgress,
                                    child: const Text(
                                      'Business Mate',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFEAF3FF),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 20,
                                child: Center(
                                  child: _TextReveal(
                                    progress: _textRevealProgress,
                                    child: Text(
                                      'Run your business smarter.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.74,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _logoShimmerController,
                                builder: (context, _) => CustomPaint(
                                  painter: _BrandShimmerPainter(
                                    _logoShimmerController.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _logoSparkleController,
                                builder: (context, _) => CustomPaint(
                                  painter: _BrandSparklePainter(
                                    _logoSparkleController.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double get _logoLockProgress => Curves.easeOutCubic.transform(
    const Interval(0.70, 1).transform(_growthController.value),
  );
}

class _TextReveal extends StatelessWidget {
  const _TextReveal({required this.progress, required this.child});

  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final reveal = progress.value;
        if (reveal <= 0) {
          return Opacity(opacity: 0, child: child);
        }
        if (reveal >= 0.999) {
          return child!;
        }
        final featherStart = math.max(0.0, reveal - 0.08);
        final featherEnd = math.min(1.0, reveal + 0.08);
        return Opacity(
          opacity: math.min(1.0, reveal * 2),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0, featherStart, featherEnd],
            ).createShader(bounds),
            child: child,
          ),
        );
      },
    );
  }
}

class _GrowthLinePainter extends CustomPainter {
  const _GrowthLinePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.95)
      ..quadraticBezierTo(
        size.width * 0.14,
        size.height * 0.84,
        size.width * 0.30,
        size.height * 0.66,
      )
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.63,
        size.width * 0.62,
        size.height * 0.39,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.18,
        size.width * 0.98,
        size.height * 0.01,
      );
    final metric = path.computeMetrics().single;
    final drawnPath = metric.extractPath(0, metric.length * progress);
    final glowPaint = Paint()
      ..color = const Color(
        0xFF4F8DFF,
      ).withValues(alpha: 0.16 + progress * 0.26)
      ..strokeWidth = 7 + progress * 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final linePaint = Paint()
      ..color = const Color(0xFF4F8DFF)
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawnPath, glowPaint);
    canvas.drawPath(drawnPath, linePaint);
  }

  @override
  bool shouldRepaint(_GrowthLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BrandShimmerPainter extends CustomPainter {
  const _BrandShimmerPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final sweep = Curves.easeInOutCubic.transform(progress);
    final sweepAlpha = math.sin(math.pi * progress);
    final centre = Offset(
      size.width * (-0.18 + sweep * 1.36),
      size.height * (1.08 - sweep * 1.20),
    );
    final glow = Paint()
      ..color = const Color(0xFF8AC4FF).withValues(alpha: sweepAlpha * 0.18)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final beam = Paint()
      ..color = const Color(0xFFB8DDFF).withValues(alpha: sweepAlpha * 0.34)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final start = centre + Offset(-size.width * 0.26, size.height * 0.26);
    final end = centre + Offset(size.width * 0.26, -size.height * 0.26);
    canvas.drawLine(start, end, glow);
    canvas.drawLine(start, end, beam);
  }

  @override
  bool shouldRepaint(_BrandShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BrandSparklePainter extends CustomPainter {
  const _BrandSparklePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final sparkleAlpha = math.sin(math.pi * progress);
    final sparkle = Paint()
      ..color = const Color(0xFFD4EBFF).withValues(alpha: sparkleAlpha)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final sparkleCentre = Offset(size.width * 0.64, size.height * 0.13);
    canvas.drawCircle(sparkleCentre, 1.7, sparkle);
    canvas.drawLine(
      sparkleCentre - const Offset(4, 0),
      sparkleCentre + const Offset(4, 0),
      sparkle,
    );
    canvas.drawLine(
      sparkleCentre - const Offset(0, 4),
      sparkleCentre + const Offset(0, 4),
      sparkle,
    );
  }

  @override
  bool shouldRepaint(_BrandSparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BusinessMateLogoPainter extends CustomPainter {
  const _BusinessMateLogoPainter({
    required this.barProgress,
    required this.breath,
    required this.pulse,
    required this.strike,
    required this.shimmer,
  });

  final double barProgress;
  final double breath;
  final double pulse;
  final double strike;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final hexagon = _hexagonPath(size);
    final pulseStrength = math.sin(math.pi * pulse);
    final strikeStrength = math.sin(math.pi * strike);
    final glowStrength =
        breath * 0.08 + pulseStrength * 0.28 + strikeStrength * 0.05;
    if (glowStrength > 0) {
      final glow = Paint()
        ..color = const Color(0xFF4F8DFF).withValues(alpha: glowStrength)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawPath(hexagon, glow);
    }
    if (strikeStrength > 0) {
      final strikeLight = Paint()
        ..color = const Color(
          0xFF4F8DFF,
        ).withValues(alpha: strikeStrength * 0.055)
        ..style = PaintingStyle.fill;
      canvas.drawPath(hexagon, strikeLight);
    }
    final outline = Paint()
      ..color = const Color(0xFF4F8DFF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hexagon, outline);

    final bars = Paint()
      ..color = const Color(
        0xFFEAF3FF,
      ).withValues(alpha: 0.35 + barProgress * 0.65)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final baseline = size.height * 0.66;
    _drawBar(
      canvas,
      bars,
      start: Offset(size.width * 0.32, baseline),
      end: Offset(size.width * 0.32, size.height * 0.55),
    );
    _drawBar(
      canvas,
      bars,
      start: Offset(size.width * 0.50, baseline),
      end: Offset(size.width * 0.50, size.height * 0.43),
    );
    _drawBar(
      canvas,
      bars,
      start: Offset(size.width * 0.68, baseline),
      end: Offset(size.width * 0.68, size.height * 0.30),
    );

    if (shimmer > 0) {
      canvas.save();
      canvas.clipPath(hexagon);
      final sweep = size.width * (shimmer * 1.8 - 0.4);
      final shimmerPaint = Paint()
        ..shader =
            LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFB8DDFF).withValues(alpha: 0.94),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(
                sweep - size.width * 0.22,
                0,
                size.width * 0.44,
                size.height,
              ),
            );
      canvas.drawRect(Offset.zero & size, shimmerPaint);
      canvas.restore();
    }
  }

  void _drawBar(
    Canvas canvas,
    Paint paint, {
    required Offset start,
    required Offset end,
  }) {
    canvas.drawLine(start, Offset.lerp(start, end, barProgress)!, paint);
  }

  Path _hexagonPath(Size size) {
    final path = Path();
    final centre = Offset(size.width / 2, size.height / 2);
    const radiusFactor = 0.41;
    for (var index = 0; index < 6; index++) {
      final radians = (-90 + index * 60) * math.pi / 180;
      final point = Offset(
        centre.dx + size.width * radiusFactor * math.cos(radians),
        centre.dy + size.height * radiusFactor * math.sin(radians),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BusinessMateLogoPainter oldDelegate) =>
      oldDelegate.barProgress != barProgress ||
      oldDelegate.breath != breath ||
      oldDelegate.pulse != pulse ||
      oldDelegate.strike != strike ||
      oldDelegate.shimmer != shimmer;
}
