import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BotaoPerfil extends StatelessWidget {
  final String texto;
  final IconData icone;
  final Color cor;
  final VoidCallback onPressed;

  const BotaoPerfil({
    super.key,
    required this.texto,
    required this.icone,
    required this.cor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icone, size: 28),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 6,
        ),
      ),
    );
  }
}
