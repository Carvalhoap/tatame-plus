import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/training_type.dart';
import '../repository/training_type_repository.dart';

class TrainingTypesScreen extends StatefulWidget {
  const TrainingTypesScreen({super.key});

  @override
  State<TrainingTypesScreen> createState() => _TrainingTypesScreenState();
}

class _TrainingTypesScreenState extends State<TrainingTypesScreen> {
  Future<List<TrainingType>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= load();
  }

  Future<List<TrainingType>> load() async {
    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      throw StateError('Nenhum usuário autenticado foi encontrado.');
    }

    return context.read<TrainingTypeRepository>().getTrainingTypes(
      academyId: currentUser.academyId,
    );
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  Future<void> openForm({TrainingType? trainingType}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _TrainingTypeDialog(trainingType: trainingType),
    );

    if (!mounted) {
      return;
    }

    if (changed == true) {
      reload();
    }
  }

  Future<void> toggleActive(TrainingType trainingType) async {
    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await context.read<TrainingTypeRepository>().setTrainingTypeActive(
        academyId: currentUser.academyId,
        trainingTypeId: trainingType.id,
        isActive: !trainingType.isActive,
        updatedBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      reload();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError('Não foi possível alterar o tipo de treino: $error');
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
        title: const Text('Tipos de Treino'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo tipo'),
      ),
      body: FutureBuilder<List<TrainingType>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(onRetry: reload);
          }

          final types = snapshot.data ?? const [];

          if (types.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: types.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final trainingType = types[index];

                return _TrainingTypeCard(
                  trainingType: trainingType,
                  onTap: () => openForm(trainingType: trainingType),
                  onToggleActive: () => toggleActive(trainingType),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TrainingTypeDialog extends StatefulWidget {
  final TrainingType? trainingType;

  const _TrainingTypeDialog({this.trainingType});

  bool get isEditing => trainingType != null;

  @override
  State<_TrainingTypeDialog> createState() => _TrainingTypeDialogState();
}

class _TrainingTypeDialogState extends State<_TrainingTypeDialog> {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();

  final descriptionController = TextEditingController();

  bool isActive = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    final trainingType = widget.trainingType;

    if (trainingType != null) {
      nameController.text = trainingType.name;

      descriptionController.text = trainingType.description;

      isActive = trainingType.isActive;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (isLoading) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final session = context.read<SessionService>();

    final currentUser = session.currentUser;

    if (currentUser == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final repository = context.read<TrainingTypeRepository>();

      if (widget.isEditing) {
        await repository.updateTrainingType(
          academyId: currentUser.academyId,
          trainingTypeId: widget.trainingType!.id,
          name: nameController.text,
          description: descriptionController.text,
          isActive: isActive,
          updatedBy: currentUser.id,
        );
      } else {
        await repository.createTrainingType(
          academyId: currentUser.academyId,
          name: nameController.text,
          description: descriptionController.text,
          isActive: isActive,
          createdBy: currentUser.id,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível salvar: $error'),
          backgroundColor: AppColors.gracieRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEditing ? 'Editar tipo de treino' : 'Novo tipo de treino',
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Informe o nome.';
                    }

                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nome do tipo de treino',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isActive ? 'Tipo ativo' : 'Tipo inativo'),
                  value: isActive,
                  onChanged: isLoading
                      ? null
                      : (value) {
                          setState(() {
                            isActive = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: isLoading ? null : save,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(isLoading ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}

class _TrainingTypeCard extends StatelessWidget {
  final TrainingType trainingType;

  final VoidCallback onTap;
  final VoidCallback onToggleActive;

  const _TrainingTypeCard({
    required this.trainingType,
    required this.onTap,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.sports_martial_arts)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainingType.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    if (trainingType.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        trainingType.description,
                        style: const TextStyle(color: AppColors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: trainingType.isActive,
                onChanged: (_) => onToggleActive(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_martial_arts, size: 64, color: AppColors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum tipo de treino cadastrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Crie os tipos utilizados pela academia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}
