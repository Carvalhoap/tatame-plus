import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../repository/auth_repository.dart';
import '../services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController(
    text: 'alexandre@tatameplus.app',
  );

  final passwordController = TextEditingController(
    text: '123456',
  );

  bool isLoading = false;
  String? errorMessage;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final authRepository = context.read<AuthRepository>();
    final sessionService = context.read<SessionService>();

    try {
      final user = await authRepository.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      if (user == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'E-mail ou senha inválidos.';
        });
        return;
      }

      sessionService.startSession(user);

      setState(() {
        isLoading = false;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;

        switch (error.code) {
          case 'invalid-credential':
          case 'wrong-password':
          case 'user-not-found':
            errorMessage = 'E-mail ou senha inválidos.';
            break;

          case 'user-disabled':
            errorMessage = 'Este usuário foi desativado.';
            break;

          case 'too-many-requests':
            errorMessage =
                'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
            break;

          default:
            errorMessage = 'Não foi possível entrar. Tente novamente.';
        }
      });
    } on StateError catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível entrar. Tente novamente.';
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.sports_martial_arts,
                    size: 82,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tatame+',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cada treino conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onSubmitted: (_) => login(),
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
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: AppColors.white,
                            )
                          : const Text(
                              'Entrar',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Modo demonstração',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 13,
                    ),
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