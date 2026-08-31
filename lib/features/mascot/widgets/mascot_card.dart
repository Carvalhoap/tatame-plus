import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/mascot.dart';

class MascotCard extends StatelessWidget {
  final Mascot mascot;

  const MascotCard({super.key, required this.mascot});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 110,
            child: Image.asset(mascot.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mascot.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                Text(
                  '${mascot.belt} • ${mascot.value}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mascot.description,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
