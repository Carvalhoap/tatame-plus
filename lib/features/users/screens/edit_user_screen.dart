import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/academy_member.dart';
import '../repository/user_repository.dart';

class EditUserScreen extends StatefulWidget {
  final AcademyMember member;

  const EditUserScreen({super.key, required this.member});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final Set<String> selectedRoles;
  late bool isActive;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.member.displayName);

    selectedRoles = widget.member.activeRoles.toSet();

    isActive = widget.member.isActive && widget.member.status == 'active';
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
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

  Future<void> save() async {
    if (isSaving) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (selectedRoles.isEmpty) {
      _showError('Selecione pelo menos um perfil de acesso.');
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      _showError('Sua sessão não está disponível.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await context.read<UserRepository>().updateAcademyUser(
        academyId: currentUser.academyId,
        userId: widget.member.userId,
        displayName: nameController.text.trim(),
        roles: selectedRoles.toList(growable: false),
        isActive: isActive,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário atualizado com sucesso.')),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError('Não foi possível atualizar o usuário: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar usuário'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const Text(
              'Dados da conta',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'O e-mail e a senha de acesso não serão alterados.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe o nome do usuário.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: widget.member.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Perfis de acesso',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Um usuário pode possuir mais de um perfil.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 12),
            _RoleOption(
              title: 'Aluno',
              icon: Icons.sports_martial_arts,
              selected: selectedRoles.contains('student'),
              onChanged: (value) => toggleRole('student', value),
            ),
            _RoleOption(
              title: 'Professor',
              icon: Icons.school_outlined,
              selected: selectedRoles.contains('teacher'),
              onChanged: (value) => toggleRole('teacher', value),
            ),
            _RoleOption(
              title: 'Responsável',
              icon: Icons.family_restroom,
              selected: selectedRoles.contains('guardian'),
              onChanged: (value) => toggleRole('guardian', value),
            ),
            _RoleOption(
              title: 'Administrador',
              icon: Icons.admin_panel_settings_outlined,
              selected: selectedRoles.contains('admin'),
              onChanged: (value) => toggleRole('admin', value),
            ),
            _RoleOption(
              title: 'Sócio',
              icon: Icons.business_center_outlined,
              selected: selectedRoles.contains('partner'),
              onChanged: (value) => toggleRole('partner', value),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: AppColors.white,
              child: SwitchListTile(
                value: isActive,
                title: Text(isActive ? 'Usuário ativo' : 'Usuário inativo'),
                subtitle: const Text(
                  'Usuários inativos não podem entrar no Tatame+.',
                ),
                onChanged: (value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.white,
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : save,
              icon: const Icon(Icons.save),
              label: Text(isSaving ? 'Salvando...' : 'Salvar alterações'),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _RoleOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      child: CheckboxListTile(
        value: selected,
        secondary: Icon(icon, color: AppColors.brandPrimary),
        title: Text(title),
        onChanged: (value) => onChanged(value ?? false),
      ),
    );
  }
}
