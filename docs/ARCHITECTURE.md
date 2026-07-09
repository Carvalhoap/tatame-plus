# ARCHITECTURE

Este documento define a arquitetura oficial do Tatame+.

A arquitetura só deve ser alterada quando houver uma justificativa técnica clara.

## Estrutura principal

```text
lib/
├── app/
├── core/
├── features/
└── main.dart
```

## app/

Responsável pela configuração geral da aplicação.

Exemplos:

- app.dart
- rotas futuras
- configuração inicial do app

## core/

Contém recursos compartilhados por todo o aplicativo.

```text
core/
├── theme/
├── widgets/
├── constants/
├── services/
└── utils/
```

Regras:

- Nada dentro de `core/` deve depender de uma feature específica.
- Componentes reutilizados em várias features ficam em `core/widgets`.
- Tema global fica em `core/theme`.

## features/

Cada feature representa uma área funcional do produto.

```text
features/
├── academy/
├── student/
├── teacher/
├── mascot/
├── home/
└── classroom/
```

Cada feature deve seguir este padrão:

```text
feature/
├── data/
├── models/
├── repository/
├── services/
├── screens/
└── widgets/
```

Nem todas as pastas precisam existir desde o início. Elas devem ser criadas conforme a necessidade.

## Convenção de nomes

Arquivos usam `snake_case`.

Exemplos:

- `student_screen.dart`
- `academy_model.dart`
- `graduation_card.dart`

Classes usam `PascalCase`.

Exemplos:

- `StudentScreen`
- `GraduationCard`
- `Academy`

Variáveis e métodos usam `camelCase`.

Exemplos:

- `studentName`
- `monthlyGoal`
- `calculateProgress()`

## Idioma

Código em inglês.

Documentação em português.

## Models

Models representam entidades do negócio.

Exemplos:

- Academy
- Student
- Teacher
- Classroom
- Plan
- Agreement
- Attendance

Regras:

- Models não devem conter lógica visual.
- Models não devem conhecer widgets.
- Models devem representar dados e regras simples.
- Todo dado principal deve possuir `id`.
- Todo dado pertencente a uma academia deve possuir `academyId`.

## Theme

O tema visual do aplicativo fica em:

```text
core/theme/
```

Arquivos atuais:

- `app_colors.dart`
- `app_text_styles.dart`
- `app_theme.dart`

Regras:

- Não usar `Color(...)` diretamente em telas.
- Preferir `AppColors` e `AppTextStyles`.

## Permissões

Perfis atuais:

```text
admin
partner
teacher
student
guardian
```

Regras:

- Informações financeiras só podem ser vistas por `admin` e `partner`.
- Professor não acessa planos, convênios ou valores.
- Aluno acessa apenas sua própria jornada.
- Responsável acessa apenas alunos vinculados.

## Fluxo de desenvolvimento

Toda funcionalidade deve seguir este fluxo:

```text
Regra de negócio
↓
Model
↓
Mock ou Repository
↓
Tela
↓
Teste
↓
Commit
↓
Changelog
```

## Commits

Usaremos commits em inglês.

Formato:

```text
feat(scope): description
fix(scope): description
docs(scope): description
refactor(scope): description
```

Exemplos:

- `feat(student): add belt journey card`
- `feat(mascot): add belt mascot system`
- `docs(architecture): define project architecture`

## Regra de tamanho

- Até 300 linhas: aceitável.
- Acima de 300 linhas: avaliar separação.
- Acima de 500 linhas: refatoração obrigatória.

## Princípios

O Tatame+ segue estes princípios:

- Código limpo
- Baixo acoplamento
- Alta coesão
- Organização por features
- Segurança por padrão
- Escalabilidade
- Experiência do usuário como prioridade

## Decisão oficial

Esta é a arquitetura base do Tatame+.

Mudanças estruturais só devem ser feitas quando trouxerem ganho claro de manutenção, segurança, escalabilidade ou clareza.