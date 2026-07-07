import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TeacherScreen extends StatelessWidget {
  const TeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Painel do Professor'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👨‍🏫 Bem-vindo, professor',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Aqui você acompanhará presenças, metas e evolução dos alunos.',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}