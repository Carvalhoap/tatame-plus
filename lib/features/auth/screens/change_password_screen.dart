import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../repository/auth_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isSaving = false;
  bool showCurrentPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;
  String? errorMessage;

  Future<void> changePassword() async {
    if (isSaving) {
      return;
    }

    final currentPassword = currentPasswordController.text;
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      setState(() {
        errorMessage = 'A confirmação não corresponde à nova senha.';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      await context.read<AuthRepository>().changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 48,
          ),
          title: const Text('Senha alterada'),
          content: const Text(
            'Sua nova senha foi salva com sucesso.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Concluir'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } on PasswordManagementException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
        errorMessage = 'Não foi possível alterar a senha. Tente novamente.';
      });
    }
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration passwordDecoration({
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        tooltip: isVisible ? 'Ocultar senha' : 'Mostrar senha',
        icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alterar minha senha'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.password_outlined,
                      size: 68,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Proteja sua conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use pelo menos 8 caracteres e não compartilhe '
                      'sua senha.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: currentPasswordController,
                      obscureText: !showCurrentPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                      decoration: passwordDecoration(
                        label: 'Senha atual',
                        isVisible: showCurrentPassword,
                        onToggleVisibility: () {
                          setState(() {
                            showCurrentPassword = !showCurrentPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: newPasswordController,
                      obscureText: !showNewPassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: passwordDecoration(
                        label: 'Nova senha',
                        isVisible: showNewPassword,
                        onToggleVisibility: () {
                          setState(() {
                            showNewPassword = !showNewPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !showConfirmPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: passwordDecoration(
                        label: 'Confirmar nova senha',
                        isVisible: showConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            showConfirmPassword = !showConfirmPassword;
                          });
                        },
                      ),
                      onSubmitted: (_) => changePassword(),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.gracieRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : changePassword,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          isSaving ? 'Alterando...' : 'Alterar senha',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
