import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StudentScreen extends StatelessWidget {
  const StudentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Jornada do Aluno'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🥋 Sua evolução começa hoje',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Faltam poucos treinos para você atingir sua próxima meta.',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}