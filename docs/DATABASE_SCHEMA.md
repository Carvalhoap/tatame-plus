# DATABASE SCHEMA

## Tatame+ — Modelo do Cloud Firestore

Versão do documento: 1.0  
Status: Arquitetura aprovada para o MVP

Este documento define a estrutura oficial do banco de dados do Tatame+.

O Tatame+ é uma plataforma multiacademia. Todos os dados operacionais pertencem a uma academia específica.

---

## 1. Princípios

### 1.1 Usuário não é permissão

O usuário representa a identidade da pessoa.

As permissões são definidas separadamente para cada academia.

Exemplo:

```text
Alexandre Carvalho
│
├── GB Neves
│   ├── admin
│   ├── teacher
│   └── student
│
└── Outra academia
    └── student
```

### 1.2 Uma única fonte da verdade

Relacionamentos não devem ser duplicados em vários documentos sem necessidade.

Exemplo:

A relação entre aluno e turma será armazenada em `classroomEnrollments`.

Não manteremos simultaneamente:

- lista de alunos dentro da turma;
- lista de turmas dentro do aluno.

### 1.3 Dados operacionais pertencem à academia

Turmas, alunos, planos, graduações, sessões e presenças ficam abaixo de:

```text
academies/{academyId}
```

### 1.4 IDs não devem conter dados pessoais

Não usar CPF, e-mail, telefone ou nome como ID de documento.

### 1.5 Exclusão lógica

Dados importantes não serão apagados diretamente pela interface comum.

Utilizaremos campos como:

```text
isActive
status
archivedAt
```

Isso preserva histórico e auditoria.

---

# 2. Estrutura principal

```text
users
└── {uid}

academies
└── {academyId}
    ├── members
    ├── students
    ├── teachers
    ├── guardians
    ├── classrooms
    ├── classroomSchedules
    ├── classroomEnrollments
    ├── classroomTeachers
    ├── plans
    ├── agreements
    ├── enrollments
    ├── checkInSessions
    ├── graduationPrograms
    ├── studentGraduationProgress
    ├── payments
    └── auditLogs
```

---

# 3. Usuários globais

## Caminho

```text
users/{uid}
```

O ID do documento será o UID fornecido pelo Firebase Authentication.

## Campos

```text
displayName: string
email: string
photoUrl: string | null
phone: string | null
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Exemplo

```json
{
  "displayName": "Alexandre Carvalho",
  "email": "alexandre@email.com",
  "photoUrl": null,
  "phone": "21999999999",
  "isActive": true
}
```

## Regras

- O documento não guarda as funções do usuário.
- Os perfis serão definidos por academia.
- O usuário poderá atualizar apenas informações pessoais permitidas.
- O usuário não poderá conceder permissões a si próprio.

---

# 4. Academias

## Caminho

```text
academies/{academyId}
```

## Campos

```text
name: string
slug: string
timezone: string
isActive: boolean
createdBy: string
createdAt: timestamp
updatedAt: timestamp
```

## Exemplo

```json
{
  "name": "Gracie Barra Neves",
  "slug": "gracie-barra-neves",
  "timezone": "America/Sao_Paulo",
  "isActive": true,
  "createdBy": "firebase_uid"
}
```

---

# 5. Membros e permissões

## Caminho

```text
academies/{academyId}/members/{uid}
```

O ID do documento será o UID do usuário.

## Campos

```text
userId: string
roles: array<string>
status: string
joinedAt: timestamp
updatedAt: timestamp
authorizedBy: string
rolesUpdatedAt: timestamp
```

## Perfis permitidos

```text
admin
partner
teacher
student
guardian
```

## Exemplo

```json
{
  "userId": "firebase_uid",
  "roles": [
    "admin",
    "teacher",
    "student"
  ],
  "status": "active",
  "authorizedBy": "admin_uid"
}
```

## Regras

- Somente administrador pode adicionar ou remover perfis.
- O usuário não pode alterar a própria lista de perfis.
- Trocar o contexto ativo não altera as permissões.
- Toda alteração de perfil deverá gerar um registro de auditoria.
- Alterações sensíveis serão futuramente executadas por Cloud Function.

---

# 6. Alunos

## Caminho

```text
academies/{academyId}/students/{studentId}
```

## Campos

```text
userId: string | null
fullName: string
birthDate: timestamp
phone: string | null
email: string | null
photoUrl: string | null
guardianIds: array<string>
isMinor: boolean
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Observações

- `userId` poderá ser nulo para crianças sem login próprio.
- Crianças serão acessadas pelos responsáveis vinculados.
- Dados de plano, convênio, turma, pagamento e graduação não ficam diretamente no aluno.

---

# 7. Responsáveis

## Caminho

```text
academies/{academyId}/guardians/{guardianId}
```

## Campos

```text
userId: string
studentIds: array<string>
relationship: string | null
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Regras

- Um responsável pode acompanhar vários alunos.
- Um aluno pode possuir mais de um responsável.
- O responsável acessa somente os alunos aos quais está vinculado.

---

# 8. Professores

## Caminho

```text
academies/{academyId}/teachers/{teacherId}
```

## Campos

```text
userId: string
fullName: string
phone: string
email: string
photoUrl: string | null
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

O professor é um perfil operacional separado da identidade global do usuário.

---

# 9. Turmas

## Caminho

```text
academies/{academyId}/classrooms/{classroomId}
```

## Campos

```text
name: string
description: string
audience: string
capacity: number | null
graduationProgramId: string | null
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Valores iniciais de audience

```text
kids
teens
adult
women
noGi
custom
```

## Exemplo

```json
{
  "name": "Adulto Noite",
  "description": "Turma adulta com kimono",
  "audience": "adult",
  "capacity": null,
  "graduationProgramId": "adult_program",
  "isActive": true
}
```

---

# 10. Horários das turmas

## Caminho

```text
academies/{academyId}/classroomSchedules/{scheduleId}
```

## Campos

```text
classroomId: string
dayOfWeek: number
startMinutes: number
endMinutes: number
location: string | null
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Convenções

```text
dayOfWeek:
1 = segunda-feira
2 = terça-feira
3 = quarta-feira
4 = quinta-feira
5 = sexta-feira
6 = sábado
7 = domingo
```

Os horários serão armazenados como minutos após meia-noite.

Exemplo:

```text
20:30 = 1230
21:30 = 1290
```

Isso facilita ordenação e comparação sem depender de uma data específica.

---

# 11. Relação entre alunos e turmas

## Caminho

```text
academies/{academyId}/classroomEnrollments/{classroomEnrollmentId}
```

## Campos

```text
studentId: string
classroomId: string
status: string
startedAt: timestamp
endedAt: timestamp | null
createdAt: timestamp
updatedAt: timestamp
```

## Status

```text
active
paused
finished
cancelled
```

Essa coleção será a única fonte oficial do vínculo entre aluno e turma.

---

# 12. Relação entre professores e turmas

## Caminho

```text
academies/{academyId}/classroomTeachers/{classroomTeacherId}
```

## Campos

```text
teacherId: string
classroomId: string
isLeadTeacher: boolean
startedAt: timestamp
endedAt: timestamp | null
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

Uma turma pode ter vários professores.

Um professor pode atuar em várias turmas.

---

# 13. Planos

## Caminho

```text
academies/{academyId}/plans/{planId}
```

## Campos

```text
name: string
description: string
priceInCents: number
billingPeriod: string
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Exemplo

```json
{
  "name": "Adulto Livre",
  "description": "Acesso às turmas adultas autorizadas",
  "priceInCents": 18000,
  "billingPeriod": "monthly",
  "isActive": true
}
```

Valores financeiros serão armazenados em centavos.

Exemplo:

```text
R$ 180,00 = 18000
```

---

# 14. Convênios e formas de vínculo

## Caminho

```text
academies/{academyId}/agreements/{agreementId}
```

## Campos

```text
name: string
description: string
type: string
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Tipos iniciais

```text
monthly
gympass
totalpass
family
scholarshipPartial
scholarshipFull
special
socialProject
other
```

Plano representa o produto contratado.

Convênio representa a forma de pagamento ou condição comercial.

---

# 15. Matrículas

## Caminho

```text
academies/{academyId}/enrollments/{enrollmentId}
```

## Campos

```text
studentId: string
planId: string
agreementId: string
status: string
discountPercent: number
customPriceInCents: number | null
startedAt: timestamp
endedAt: timestamp | null
createdAt: timestamp
updatedAt: timestamp
```

## Status

```text
active
paused
cancelled
finished
```

A matrícula preserva o histórico comercial do aluno.

O aluno continua existindo mesmo quando uma matrícula é encerrada.

---

# 16. Sessões de check-in

## Caminho

```text
academies/{academyId}/checkInSessions/{sessionId}
```

## Campos

```text
academyId: string
classroomId: string
teacherId: string
scheduleId: string | null
status: string
createdAt: timestamp
expiresAt: timestamp
closedAt: timestamp | null
createdBy: string
attendanceCount: number
```

## Status

```text
active
expired
closed
cancelled
```

## QR Code

O QR Code conterá somente:

```text
sessionId
```

O aplicativo consulta o Firestore para validar:

- existência da sessão;
- academia;
- turma;
- validade;
- status.

---

# 17. Presenças

## Caminho

```text
academies/{academyId}/checkInSessions/{sessionId}/attendances/{studentId}
```

O ID do documento será o `studentId`.

Essa decisão impede naturalmente dois documentos de presença do mesmo aluno na mesma sessão.

## Campos

```text
academyId: string
sessionId: string
studentId: string
classroomId: string
teacherId: string
source: string
status: string
checkedInAt: timestamp
registeredBy: string
invalidatedAt: timestamp | null
invalidatedBy: string | null
invalidationReason: string | null
```

## Source

```text
qrCode
manual
import
```

## Status

```text
valid
invalidated
```

## Regras

- O aluno só pode registrar presença para si.
- A sessão precisa estar ativa e dentro da validade.
- O aluno precisa pertencer à academia.
- O aluno precisa estar autorizado para a turma.
- Professor autorizado poderá registrar presença manual.
- Administrador poderá invalidar presença.
- Presenças não serão apagadas; serão invalidadas.

O registro da presença e o incremento de `attendanceCount` deverão ocorrer em uma transação.

---

# 18. Programas de graduação

## Caminho

```text
academies/{academyId}/graduationPrograms/{programId}
```

## Campos

```text
name: string
audience: string
isActive: boolean
createdAt: timestamp
updatedAt: timestamp
```

## Subcoleção de etapas

```text
academies/{academyId}/graduationPrograms/{programId}/stages/{stageId}
```

## Campos da etapa

```text
name: string
beltColor: string
order: number
criterion: string
requiredAttendances: number | null
minimumDurationMonths: number | null
stripeConfiguration: array<map>
nextStageId: string | null
isActive: boolean
```

## Critérios

```text
attendance
time
attendanceAndTime
manual
```

---

# 19. Progresso de graduação do aluno

## Caminho

```text
academies/{academyId}/studentGraduationProgress/{studentId}
```

## Campos

```text
studentId: string
graduationProgramId: string
currentStageId: string
stageStartedAt: timestamp
validAttendances: number
stripeProgress: array<map>
estimatedCompletionAt: timestamp | null
eligibilityStatus: string
approvedByTeacher: boolean
approvedBy: string | null
approvedAt: timestamp | null
updatedAt: timestamp
```

## Elegibilidade

```text
notEligible
almostEligible
eligible
approved
```

## Histórico

```text
academies/{academyId}/studentGraduationProgress/{studentId}/history/{historyId}
```

Campos:

```text
fromStageId: string | null
toStageId: string
graduatedAt: timestamp
approvedBy: string
notes: string | null
```

O sistema calcula elegibilidade, mas não gradua automaticamente.

---

# 20. Pagamentos

## Caminho futuro

```text
academies/{academyId}/payments/{paymentId}
```

## Campos iniciais previstos

```text
studentId: string
enrollmentId: string
referenceMonth: string
amountInCents: number
dueDate: timestamp
paidAt: timestamp | null
status: string
paymentMethod: string | null
createdAt: timestamp
updatedAt: timestamp
```

## Status

```text
pending
paid
overdue
cancelled
waived
```

O módulo financeiro será implementado em uma versão posterior.

---

# 21. Auditoria

## Caminho

```text
academies/{academyId}/auditLogs/{auditLogId}
```

## Campos

```text
action: string
entityType: string
entityId: string
performedBy: string
createdAt: timestamp
before: map | null
after: map | null
metadata: map | null
```

## Eventos obrigatórios

```text
userRolesChanged
attendanceInvalidated
graduationApproved
paymentChanged
studentArchived
classroomChanged
```

Registros de auditoria não poderão ser alterados pela interface comum.

---

# 22. Consultas principais

## Turmas ativas

```text
classrooms
where isActive == true
```

## Turmas de um aluno

```text
classroomEnrollments
where studentId == studentId
where status == active
```

## Alunos de uma turma

```text
classroomEnrollments
where classroomId == classroomId
where status == active
```

## Professores de uma turma

```text
classroomTeachers
where classroomId == classroomId
where isActive == true
```

## Sessões abertas

```text
checkInSessions
where classroomId == classroomId
where status == active
```

## Presenças de uma sessão

```text
checkInSessions/{sessionId}/attendances
where status == valid
orderBy checkedInAt
```

## Histórico de presença de um aluno

Consulta por grupo de coleção:

```text
collectionGroup("attendances")
where academyId == academyId
where studentId == studentId
where status == valid
orderBy checkedInAt
```

---

# 23. Índices previstos

O Firestore solicitará índices conforme as consultas forem implementadas.

Índices compostos inicialmente previstos:

```text
classroomEnrollments:
studentId + status

classroomEnrollments:
classroomId + status

classroomTeachers:
classroomId + isActive

checkInSessions:
classroomId + status + createdAt

attendances collection group:
academyId + studentId + status + checkedInAt

payments:
studentId + status + dueDate
```

Os índices serão criados somente quando uma consulta real exigir.

---

# 24. Segurança

O banco permanecerá bloqueado até a implementação do Firebase Authentication.

A segurança será baseada em:

```text
request.auth.uid
membership da academia
roles autorizados
vínculos do aluno
vínculos do responsável
turmas do professor
```

Funções planejadas nas regras:

```text
isSignedIn()
isAcademyMember(academyId)
hasRole(academyId, role)
isAdmin(academyId)
isTeacher(academyId)
isStudentOwner(studentId)
isGuardianOf(studentId)
```

## Regras críticas

- Usuário não altera seus próprios perfis.
- Apenas administrador autorizado altera perfis.
- Aluno lê apenas seus próprios dados.
- Responsável lê apenas alunos vinculados.
- Professor acessa apenas dados pedagógicos autorizados.
- Professor não acessa informações financeiras.
- Admin e partner acessam informações administrativas conforme autorização.
- Toda consulta deve ser compatível com as regras de segurança.

---

# 25. Timestamps

Campos como:

```text
createdAt
updatedAt
checkedInAt
approvedAt
```

deverão utilizar horário gerado pelo servidor sempre que possível.

Não confiar exclusivamente no relógio do celular.

---

# 26. Transações

Utilizar transações ou operações em lote quando duas ou mais gravações precisarem acontecer juntas.

Exemplo do check-in:

```text
1. Verificar se a sessão está ativa
2. Verificar se a presença já existe
3. Criar a presença
4. Incrementar attendanceCount
```

Ou todas as operações são confirmadas, ou nenhuma é aplicada.

---

# 27. Exclusões

Documentos com subcoleções não serão excluídos diretamente pela interface.

Exemplo:

```text
checkInSession
└── attendances
```

Excluir somente a sessão não exclui suas presenças.

Por isso utilizaremos:

```text
status
isActive
archivedAt
```

Exclusões físicas futuras serão feitas por processos administrativos controlados.

---

# 28. Decisões congeladas para o MVP

As seguintes decisões são oficiais:

1. Identidade global em `users/{uid}`.
2. Perfis por academia em `members/{uid}`.
3. Usuário pode possuir vários perfis.
4. Apenas administrador altera perfis.
5. Dados operacionais ficam abaixo da academia.
6. Relações aluno-turma ficam em `classroomEnrollments`.
7. Relações professor-turma ficam em `classroomTeachers`.
8. Matrícula é separada do aluno.
9. Sessão de check-in é a raiz operacional da presença.
10. Presença usa `studentId` como ID dentro da sessão.
11. Presença não é apagada; pode ser invalidada.
12. Graduação é separada do aluno.
13. Valores monetários são armazenados em centavos.
14. Datas importantes usam timestamps do servidor.
15. Exclusão lógica é preferida.
16. Segurança será aplicada antes de liberar gravações no aplicativo.

---

# 29. Próximas etapas

1. Implementar Firebase Authentication.
2. Criar regras iniciais de membros e usuários.
3. Criar o primeiro administrador da academia.
4. Implementar `FirestoreCheckInSessionRepository`.
5. Implementar sessão em tempo real.
6. Implementar registro transacional de presença.
7. Testar professor e aluno em dispositivos diferentes.