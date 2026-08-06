import 'package:flutter/material.dart';

import '../../features/graduation/models/belt_color.dart';
import '../../features/graduation/models/stripe_progress.dart';

class GraduationBeltWidget extends StatelessWidget {
  final BeltColor beltColor;
  final List<StripeProgress> stripes;
  final double height;

  const GraduationBeltWidget({
    super.key,
    required this.beltColor,
    required this.stripes,
    this.height = 78,
  });

  @override
  Widget build(BuildContext context) {
    final beltColors = _getBeltColors(beltColor);

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: beltColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: beltColor == BeltColor.white
              ? Colors.black26
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: _BeltStitching(),
            ),
          ),
          _RankBar(stripes: stripes, beltColor: beltColor),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  List<Color> _getBeltColors(BeltColor belt) {
    switch (belt) {
      case BeltColor.white:
        return const [Color(0xFFF9F9F9), Color(0xFFE2E2E2)];

      case BeltColor.greyWhite:
        return const [Color(0xFFF4F4F4), Color(0xFF9E9E9E)];

      case BeltColor.grey:
        return const [Color(0xFFBDBDBD), Color(0xFF757575)];

      case BeltColor.greyBlack:
        return const [Color(0xFF9E9E9E), Color(0xFF212121)];

      case BeltColor.yellowWhite:
        return const [Color(0xFFFFF8E1), Color(0xFFFDD835)];

      case BeltColor.yellow:
        return const [Color(0xFFFFEB3B), Color(0xFFF9A825)];

      case BeltColor.yellowBlack:
        return const [Color(0xFFFDD835), Color(0xFF212121)];

      case BeltColor.orangeWhite:
        return const [Color(0xFFFFF3E0), Color(0xFFFB8C00)];

      case BeltColor.orange:
        return const [Color(0xFFFFA726), Color(0xFFEF6C00)];

      case BeltColor.orangeBlack:
        return const [Color(0xFFFB8C00), Color(0xFF212121)];

      case BeltColor.greenWhite:
        return const [Color(0xFFE8F5E9), Color(0xFF43A047)];

      case BeltColor.green:
        return const [Color(0xFF43A047), Color(0xFF1B5E20)];

      case BeltColor.greenBlack:
        return const [Color(0xFF2E7D32), Color(0xFF212121)];

      case BeltColor.blue:
        return const [Color(0xFF1976D2), Color(0xFF0D47A1)];

      case BeltColor.purple:
        return const [Color(0xFF8E24AA), Color(0xFF4A148C)];

      case BeltColor.brown:
        return const [Color(0xFF795548), Color(0xFF3E2723)];

      case BeltColor.black:
        return const [Color(0xFF303030), Color(0xFF050505)];

      case BeltColor.redBlack:
        return const [Color(0xFFC62828), Color(0xFF111111)];

      case BeltColor.redWhite:
        return const [Color(0xFFC62828), Color(0xFFF5F5F5)];

      case BeltColor.red:
        return const [Color(0xFFD32F2F), Color(0xFF8E0000)];
    }
  }
}

class _RankBar extends StatelessWidget {
  final List<StripeProgress> stripes;
  final BeltColor beltColor;

  const _RankBar({required this.stripes, required this.beltColor});

  @override
  Widget build(BuildContext context) {
    final earnedStripes = <StripeColor>[];

    for (final stripeGroup in stripes) {
      for (var index = 0; index < stripeGroup.earned; index++) {
        earnedStripes.add(stripeGroup.color);
      }
    }

    return Container(
      width: 116,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _rankBarColor,
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: earnedStripes
            .take(11)
            .map(
              (stripeColor) => Container(
                width: 6,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _stripeColor(stripeColor),
                  borderRadius: BorderRadius.circular(1),
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Color get _rankBarColor {
    switch (beltColor) {
      case BeltColor.black:
      case BeltColor.redBlack:
      case BeltColor.redWhite:
      case BeltColor.red:
        return const Color(0xFFC62828);

      default:
        return const Color(0xFF111111);
    }
  }

  Color _stripeColor(StripeColor color) {
    switch (color) {
      case StripeColor.white:
        return Colors.white;

      case StripeColor.red:
        return const Color(0xFFD32F2F);

      case StripeColor.black:
        return Colors.black;
    }
  }
}

class _BeltStitching extends StatelessWidget {
  const _BeltStitching();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Container(height: 1, color: Colors.black26),
        Container(height: 1, color: Colors.black26),
      ],
    );
  }
}
