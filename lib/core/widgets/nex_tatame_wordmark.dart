import 'package:flutter/material.dart';

class NexTatameWordmark extends StatelessWidget {
  final double height;
  final bool inverse;

  const NexTatameWordmark({
    super.key,
    required this.height,
    this.inverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NexTatame',
      image: true,
      child: Image.asset(
        inverse
            ? 'assets/brand/nex_tatame_wordmark_dark.png'
            : 'assets/brand/nex_tatame_wordmark.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
