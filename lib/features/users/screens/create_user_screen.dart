import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../repository/user_repository.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool isActive = true;
  bool isLoading = false;
  bool obscurePassword = true;

  final Set<String> selectedRoles = {'student'};

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> saveUser() async {
    if (isLoading) {
      return;
    }

    final form = formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    if (selectedRoles.isEmpty) {
      _showError('Selecione pelo menos um perfil de acesso.');
      return;
    }

    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      _showError('Sua sessão não está disponível. Entre novamente no Tatame+.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await context.read<UserRepository>().createAcademyUser(
        academyId: currentUser.academyId,
        displayName: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        phone: phoneController.text.trim().isEmpty
            ? null
            : phoneController.text.trim(),
        roles: selectedRoles.toList(growable: false),
        isActive: isActive,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário cadastrado com sucesso.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.gracieRed),
      );
  }

  String? validateName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Informe o nome.';
    }

    if (text.length < 3) {
      return 'Informe o nome completo.';
    }

    return null;
  }

  String? validateEmail(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Informe o e-mail.';
    }

    final emailExpression = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailExpression.hasMatch(text)) {
      return 'Informe um e-mail válido.';
    }

    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Informe uma senha provisória.';
    }

    if (password.length < 8) {
      return 'A senha precisa ter pelo menos 8 caracteres.';
    }

    return null;
  }

  void toggleRole(String role, bool selected) {
    setState(() {
      if (selected) {
        selectedRoles.add(role);
      } else {
        selectedRoles.remove(role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Novo usuário'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              const _SectionHeader(
                title: 'Dados pessoais',
                subtitle: 'Informações básicas para identificação do usuário.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: validateName,
                decoration: _inputDecoration(
                  label: 'Nome completo',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: validateEmail,
                decoration: _inputDecoration(
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: 'Telefone',
                  icon: Icons.phone_outlined,
                  optional: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                validator: validatePassword,
                onFieldSubmitted: (_) => saveUser(),
                decoration:
                    _inputDecoration(
                      label: 'Senha provisória',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      helperText:
                          'Mínimo de 8 caracteres. O usuário poderá alterá-la depois.',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 30),
              const _SectionHeader(
                title: 'Perfis de acesso',
                subtitle: 'Um mesmo usuário pode exercer mais de uma função.',
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: 'Aluno',
                subtitle: 'Área do aluno, evolução, presença e QR Code.',
                icon: Icons.sports_martial_arts,
                value: selectedRoles.contains('student'),
                onChanged: (value) {
                  toggleRole('student', value);
                },
              ),
              _RoleCard(
                title: 'Professor',
                subtitle:
                    'Acesso ao painel do professor e gerenciamento de aulas.',
                icon: Icons.school_outlined,
                value: selectedRoles.contains('teacher'),
                onChanged: (value) {
                  toggleRole('teacher', value);
                },
              ),
              _RoleCard(
                title: 'Responsável',
                subtitle: 'Acesso aos alunos vinculados ao responsável.',
                icon: Icons.family_restroom,
                value: selectedRoles.contains('guardian'),
                onChanged: (value) {
                  toggleRole('guardian', value);
                },
              ),
              _RoleCard(
                title: 'Administrador',
                subtitle: 'Permissão de gestão da academia.',
                icon: Icons.admin_panel_settings_outlined,
                value: selectedRoles.contains('admin'),
                onChanged: (value) {
                  toggleRole('admin', value);
                },
              ),
              _RoleCard(
                title: 'Sócio',
                subtitle: 'Perfil de gestão destinado aos sócios da unidade.',
                icon: Icons.business_center_outlined,
                value: selectedRoles.contains('partner'),
                onChanged: (value) {
                  toggleRole('partner', value);
                },
              ),
              const SizedBox(height: 30),
              const _SectionHeader(
                title: 'Situação',
                subtitle: 'Usuários inativos não poderão acessar o Tatame+.',
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SwitchListTile(
                  value: isActive,
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            isActive = value;
                          });
                        },
                  title: Text(
                    isActive ? 'Usuário ativo' : 'Usuário inativo',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  subtitle: Text(
                    isActive
                        ? 'O usuário poderá acessar o sistema.'
                        : 'A conta será criada, mas o acesso ficará bloqueado.',
                  ),
                  secondary: Icon(
                    isActive
                        ? Icons.check_circle_outline
                        : Icons.block_outlined,
                    color: isActive ? AppColors.success : AppColors.gracieRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : saveUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(
                isLoading ? 'Cadastrando...' : 'Cadastrar usuário',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    bool optional = false,
  }) {
    return InputDecoration(
      labelText: optional ? '$label (opcional)' : label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.grey),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: CheckboxListTile(
        value: value,
        onChanged: (newValue) {
          onChanged(newValue ?? false);
        },
        secondary: Icon(icon, color: AppColors.brandPrimary),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        subtitle: Text(subtitle),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}
