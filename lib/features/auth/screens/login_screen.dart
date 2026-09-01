import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../repository/auth_repository.dart';
import '../services/session_service.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  Future<void> login() async {
    if (isLoading) return;

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
          errorMessage = 'O usuário não pôde ser carregado.';
        });
        return;
      }

      sessionService.startSession(user);

      setState(() {
        isLoading = false;
      });
    } on FirebaseAuthException catch (error) {
      debugPrint('==========================');
      debugPrint('FirebaseAuthException');
      debugPrint('Code: ${error.code}');
      debugPrint('Message: ${error.message}');
      debugPrint('==========================');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = '${error.code}\n${error.message ?? ''}';
      });
    } on StateError catch (error) {
      debugPrint('==========================');
      debugPrint('StateError');
      debugPrint('Message: ${error.message}');
      debugPrint('==========================');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error.message;
      });
    } catch (error, stackTrace) {
      debugPrint('==========================');
      debugPrint('Erro inesperado no login');
      debugPrint('Error: $error');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==========================');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Erro inesperado: $error';
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
                    style: TextStyle(fontSize: 17, color: AppColors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
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
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onSubmitted: (_) => login(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail: emailController.text.trim(),
                                  ),
                                ),
                              );
                            },
                      child: const Text('Esqueci minha senha'),
                    ),
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
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Criar conta'),
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
