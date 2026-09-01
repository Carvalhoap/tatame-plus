import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../repository/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController emailController;

  bool isSending = false;
  bool emailSent = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController(text: widget.initialEmail);
  }

  Future<void> sendResetEmail() async {
    if (isSending) {
      return;
    }

    final email = emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Informe o e-mail usado no cadastro.';
      });
      return;
    }

    setState(() {
      isSending = true;
      errorMessage = null;
    });

    try {
      await context.read<AuthRepository>().sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      setState(() {
        isSending = false;
        emailSent = true;
      });
    } on PasswordManagementException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSending = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSending = false;
        errorMessage = 'Não foi possível enviar o e-mail. Tente novamente.';
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recuperar senha'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: emailSent
                  ? _SuccessContent(
                      email: emailController.text.trim(),
                      onBack: () => Navigator.pop(context),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_reset,
                          size: 72,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Esqueceu sua senha?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Informe seu e-mail e enviaremos um link '
                          'para criar uma nova senha.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.grey,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onSubmitted: (_) => sendResetEmail(),
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
                            onPressed: isSending ? null : sendResetEmail,
                            icon: isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(
                              isSending
                                  ? 'Enviando...'
                                  : 'Enviar link de recuperação',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: isSending
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Voltar ao login'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  final String email;
  final VoidCallback onBack;

  const _SuccessContent({required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 76,
          color: AppColors.success,
        ),
        const SizedBox(height: 18),
        const Text(
          'Confira seu e-mail',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Se existir uma conta para $email, você receberá um link '
          'para criar uma nova senha.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.grey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Verifique também a caixa de spam ou lixo eletrônico.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grey),
        ),
        const SizedBox(height: 26),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onBack,
            child: const Text('Voltar ao login'),
          ),
        ),
      ],
    );
  }
}
