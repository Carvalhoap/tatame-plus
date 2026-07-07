import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BeltJourneyCard extends StatelessWidget {
  const BeltJourneyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final belts = [
      _BeltStep('Branca', 'Furão', Colors.white, true),
      _BeltStep('Azul', 'Tigre', Colors.blue, false),
      _BeltStep('Roxa', 'Panda', Colors.purple, false),
      _BeltStep('Marrom', 'Gorila', Colors.brown, false),
      _BeltStep('Preta', 'Leão', Colors.black, false),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🥋 Jornada da Faixa',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: belts.map((belt) {
              return Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: belt.isCurrent ? 26 : 22,
                      backgroundColor: belt.color,
                      child: Text(
                        belt.mascot.substring(0, 1),
                        style: TextStyle(
                          color: belt.color == Colors.white
                              ? AppColors.black
                              : AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      belt.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            belt.isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      belt.mascot,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Você está no início da jornada. Cada treino aproxima você da próxima versão.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeltStep {
  final String name;
  final String mascot;
  final Color color;
  final bool isCurrent;

  _BeltStep(this.name, this.mascot, this.color, this.isCurrent);
}