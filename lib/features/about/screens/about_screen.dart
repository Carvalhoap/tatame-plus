import 'package:flutter/material.dart';

import '../../../app/config/app_info.dart';
import '../../../core/theme/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sobre'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.sports_martial_arts,
                  size: 72,
                  color: AppColors.brandPrimary,
                ),
                SizedBox(height: 16),
                Text(
                  AppInfo.appName,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppInfo.codename,
                  style: TextStyle(
                    fontSize: 17,
                    color: AppColors.gracieRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 28),
                _InformationRow(
                  label: 'Versão',
                  value: AppInfo.version,
                ),
                _InformationRow(
                  label: 'Data da versão',
                  value: AppInfo.releaseDate,
                ),
                Divider(height: 36),
                Text(
                  'Desenvolvido por',
                  style: TextStyle(color: AppColors.grey),
                ),
                SizedBox(height: 5),
                Text(
                  AppInfo.developer,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  'Arquitetura e mentoria técnica',
                  style: TextStyle(color: AppColors.grey),
                ),
                SizedBox(height: 5),
                Text(
                  AppInfo.technicalSupport,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 28),
                Text(
                  'Cada treino conta.',
                  style: TextStyle(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gracieRed,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;

  const _InformationRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.grey),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}