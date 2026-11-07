import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:second_chance/core/companion.dart';

class Cloudy extends StatefulWidget {
  const Cloudy({
    super.key,
    this.phase = CompanionPhase.idle,
    this.size = 110,
    this.celebrating = false,
    this.onTap,
  });

  final CompanionPhase phase;
  final double size;
  final bool celebrating;
  final VoidCallback? onTap;

  @override
  State<Cloudy> createState() => _CloudyState();
}

class _CloudyState extends State<Cloudy> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  bool _loaded = false;

  void _play() {
    if (!_loaded) return;
    _animation.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 0;
      return;
    }
    final speaking = widget.phase == CompanionPhase.speaking;
    final attentive =
        widget.phase == CompanionPhase.listening || widget.celebrating;
    final start = speaking
        ? .75
        : attentive
        ? .5
        : 0.0;
    final end = speaking
        ? .999
        : attentive
        ? .749
        : .499;
    _animation
      ..value = start
      ..repeat(
        min: start,
        max: end,
        period: Duration(
          milliseconds: speaking
              ? 900
              : attentive
              ? 1200
              : 3000,
        ),
      );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _play();
  }

  @override
  void didUpdateWidget(Cloudy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase ||
        oldWidget.celebrating != widget.celebrating) {
      _play();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.phase == CompanionPhase.speaking
        ? 'Cloudy is speaking'
        : widget.phase == CompanionPhase.listening
        ? 'Cloudy is listening'
        : 'Talk with Cloudy';
    final art = SizedBox.square(
      dimension: widget.size,
      child: Lottie.asset(
        'assets/raise_cloud.json',
        controller: _animation,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          _animation.duration = composition.duration;
          _loaded = true;
          _play();
        },
        errorBuilder: (_, _, _) =>
            const Icon(Icons.cloud_rounded, color: Color(0xFFF3FAFF), size: 80),
      ),
    );
    return Semantics(
      label: label,
      image: true,
      button: widget.onTap != null,
      child: widget.onTap == null
          ? art
          : TextButton(
              onPressed: widget.onTap,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                overlayColor: Colors.transparent,
              ),
              child: art,
            ),
    );
  }
}
