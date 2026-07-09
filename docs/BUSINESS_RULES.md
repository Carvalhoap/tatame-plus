# BUSINESS RULES

Este documento descreve todas as regras de negócio do Tatame+.

Cada regra recebe um identificador único para facilitar futuras implementações.

---

# BR-001 - Perfis de acesso

O sistema possui cinco níveis de acesso.

## Administrador

Possui acesso total ao sistema.

Pode:

- Configurar academia
- Configurar usuários
- Configurar planos
- Configurar graduações
- Configurar turmas
- Visualizar informações financeiras
- Gerenciar professores
- Gerenciar alunos
- Visualizar todos os relatórios

---

## Sócio

Possui praticamente os mesmos acessos do Administrador.

Pode visualizar:

- Financeiro
- Planos
- Convênios
- Relatórios
- Gestão completa

Não possui acesso às configurações críticas do sistema.

---

## Professor

Pode visualizar apenas informações pedagógicas.

Pode:

- Fazer chamada
- Visualizar turmas
- Visualizar evolução
- Registrar presença
- Registrar observações
- Acompanhar graduações

Não pode visualizar:

- Financeiro
- Planos dos alunos
- Gympass
- TotalPass
- Bolsas
- Convênios
- Valores

---

## Aluno

Pode visualizar apenas sua própria jornada.

Pode acessar:

- Evolução
- Missões
- Ranking
- Mascote
- Graduação
- Histórico
- Professor

Não pode visualizar dados de outros alunos.

---

## Responsável

Pode visualizar apenas os alunos vinculados ao seu cadastro.

---

# BR-002 - Academia

Todo dado do sistema pertence obrigatoriamente a uma academia.

Exemplos:

- Professor
- Aluno
- Turma
- Plano
- Convênio
- Graduação
- Ranking
- Financeiro

Não existe dado fora de uma academia.

---

# BR-003 - Turmas

Uma academia pode possuir diversas turmas.

Exemplos:

- Kids
- Juvenil
- Adulto
- No-Gi
- Manhã
- Noite
- Feminino

Cada aluno pertence a uma ou mais turmas.

Cada professor pode ministrar uma ou mais turmas.

---

# BR-004 - Presença

Toda presença pertence a:

Aluno
Turma
Professor
Data
Horário

As presenças serão utilizadas para:

- Estatísticas
- Graduação
- Ranking
- Missões
- Frequência

---

# BR-005 - Graduação

A graduação será totalmente configurável.

A academia poderá definir:

- Tempo mínimo
- Quantidade mínima de aulas
- Quantidade de graus
- Critérios adicionais

Nenhuma regra ficará fixa no código.

---

# BR-006 - Convênios e Planos

O sistema deverá permitir planos configuráveis.

Exemplos:

- Mensalista
- Gympass
- TotalPass
- Plano Família
- Bolsa Parcial
- Bolsa Integral
- Convênio Empresa
- Projeto Social

Somente Administrador e Sócio poderão visualizar essas informações.

---

# BR-007 - Financeiro

As informações financeiras são confidenciais.

Somente Administrador e Sócio possuem acesso.

---

# BR-008 - Jornada do Aluno

O aluno acompanha sua evolução através de:

- Mascote
- XP
- Faixa
- Missões
- Conquistas
- Ranking
- Histórico
- Graduação

O objetivo é incentivar constância e evolução.

---

# BR-009 - Mascotes

Cada faixa possui um mascote representando uma etapa da evolução.

Faixa Branca → Furão

Faixa Azul → Tigre

Faixa Roxa → Panda

Faixa Marrom → Gorila

Faixa Preta → Leão

Os mascotes representam a evolução do aluno durante sua jornada.

---

# BR-010 - Filosofia do Produto

O Tatame+ não é um sistema de controle de presença.

O Tatame+ é uma plataforma de evolução para academias de artes marciais.