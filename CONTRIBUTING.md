# Guia de onboarding — App Futebol de Terça

Bem-vindo ao projeto! Este guia explica o que instalar, como rodar o projeto e como trabalhamos no dia a dia. Leia uma vez do começo ao fim e volte aqui sempre que tiver dúvida.

**Stack:** SAP CAP (Node.js) no backend, SAPUI5 freestyle no frontend, Postgres em produção, deploy no Render.

---

## 1. O que instalar

| Ferramenta | Versão | Para quê |
|---|---|---|
| Git | qualquer recente | Controle de versão |
| Node.js | **20 LTS** | Roda o CAP e o UI5 |
| `@sap/cds-dk` | última | CLI do CAP (`cds watch`, `cds deploy`…) |
| VS Code | última | Editor |
| GitHub CLI (`gh`) | opcional | Abrir PRs e ver issues pelo terminal |
| Docker | opcional | Postgres local (a partir da issue #4) |

**No Windows**, use o **WSL2 com Ubuntu** e rode tudo de dentro dele (terminal, Node, git). É o mesmo ambiente do Mafra, e assim os comandos deste guia funcionam igual para os dois.

### Passo a passo (Ubuntu / WSL)

```bash
# Node 20 via nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
# feche e abra o terminal
nvm install 20
nvm use 20
node -v   # deve mostrar v20.x

# CLI do CAP
npm i -g @sap/cds-dk
cds -v

# GitHub CLI (opcional, mas recomendado)
sudo apt install gh
gh auth login
```

### Extensões do VS Code

- **SAP CDS Language Support**: autocomplete e validação de arquivos `.cds`
- **UI5 Language Assistant**: autocomplete nas views XML
- **ESLint**
- **WSL** (só no Windows): abra a pasta do projeto com `code .` de dentro do WSL

### Configure seu git

```bash
git config --global user.name "Seu Nome"
git config --global user.email "seu-email-do-github@exemplo.com"
```

---

## 2. Clonar e rodar

```bash
gh repo clone MafraFiori/futebol-terca
# ou: git clone https://github.com/MafraFiori/futebol-terca.git
cd futebol-terca
```

> ⚠️ O projeto CAP ainda não existe. Ele é criado na **issue #1**. Depois que ela for concluída, o caminho para rodar será:

```bash
npm install
cp .env.example .env     # preencha os valores (peça ao Mafra os que forem segredo)
npm run watch            # sobe o servidor local em http://localhost:4004
```

Em desenvolvimento o banco é SQLite em memória, então não precisa instalar nada. O Postgres local entra na issue #4.

---

## 3. Como o trabalho está organizado

- **Quadro:** https://github.com/users/MafraFiori/projects/1
  - View **Quadro**: colunas *A fazer → Em andamento → Em revisão → Pronto*
  - View **Sprints**: as mesmas issues agrupadas por sprint
- **Sprints = milestones.** Trabalhe sempre na sprint atual, de cima para baixo.
- **Labels** de cada issue:
  - `nível: iniciante`: pode pegar sozinho
  - `nível: intermediário`: pode pegar sozinho, mas pergunte cedo se travar
  - `nível: avançado`: **faça em dupla com o Mafra** (marque um horário antes de começar)
  - `tipo: …` e `épico: …` servem para organizar
- A **"Seção da especificação"** citada em cada issue aponta para [`docs/especificacao.md`](docs/especificacao.md). Cada issue também tem um bloco **"📖 O que a especificação pede"** com o resumo do que importa para aquela tarefa. Em caso de dúvida, a especificação é a fonte oficial.
- O campo **"Depende de"** mostra quais issues precisam estar prontas antes.

> O quadro se move quase sozinho: abrir um PR leva o card para *Em revisão*, e o merge leva para *Pronto* e fecha a issue. A única coisa manual é arrastar para **Em andamento** quando você começar.

---

## 4. Fluxo de uma issue, do início ao fim

### 1) Pegar a issue
- Abra a issue, coloque-se em **Assignees** e arraste o card para **Em andamento**.
- Leia as **Tarefas** e os **Critérios de aceite**. Se algo não estiver claro, comente na issue antes de começar.

### 2) Criar a branch
Sempre a partir da `main` atualizada:

```bash
git checkout main
git pull
git checkout -b feat/1-estrutura-cap
```

**Nome da branch:** `<tipo>/<número-da-issue>-<descrição-curta>`

| Tipo | Quando usar | Exemplo |
|---|---|---|
| `feat` | Funcionalidade nova | `feat/15-confirmar-presenca` |
| `fix` | Correção de bug | `fix/42-erro-login-celular` |
| `chore` | Configuração, infra, dependências | `chore/2-ci-github-actions` |
| `docs` | Só documentação | `docs/1-readme` |
| `refactor` | Melhoria de código sem mudar comportamento | `refactor/30-sorteio` |
| `test` | Só testes | `test/22-calculo-rating` |

### 3) Commitar
Commits pequenos, cada um com uma ideia só. Usamos **Conventional Commits em português**:

```
<tipo>: <o que foi feito, no imperativo e em minúsculas>
```

Exemplos:
```
feat: adiciona entidade Players
fix: corrige redirecionamento após login
chore: configura eslint
test: cobre cálculo de vagas na lista de espera
docs: explica como rodar localmente no README
```

```bash
git add .
git commit -m "feat: adiciona entidade Players"
git push -u origin feat/1-estrutura-cap   # na primeira vez; depois só git push
```

> Antes do `git add .`, rode `git status` e confira se não vai junto nenhum arquivo indesejado, principalmente o **`.env`**, que tem senhas e **nunca** deve ir para o GitHub.

### 4) Abrir o Pull Request
```bash
gh pr create --fill
# ou pelo site: aparece um botão "Compare & pull request" logo após o push
```

O PR já abre com um template. Preencha:
- **Closes #N** com o número da issue. É isso que liga o PR ao card e fecha a issue no merge.
- **O que mudou** e **Como testar**: escreva como se o Mafra nunca tivesse visto o código.
- **Prints/GIF** quando mexer em tela.
- **Checklist**: marque o que fez. O que não se aplica, risque ou explique.

Pode abrir o PR **antes de terminar**, como **Draft**, para pedir opinião cedo. Isso é incentivado.

### 5) Revisão
- O Mafra revisa e deixa comentários. Comentário **não é bronca**, é a parte mais importante do aprendizado.
- Para corrigir, faça novos commits na mesma branch e dê `git push`. O PR atualiza sozinho.
- Responda cada comentário ("feito", ou explique por que fez diferente).

### 6) Merge
- Com a aprovação do Mafra, clique em **Squash and merge**. Isso vira um único commit limpo na `main`.
- Apague a branch (o GitHub oferece o botão) e atualize sua máquina:

```bash
git checkout main
git pull
git branch -d feat/1-estrutura-cap
```

O card vai sozinho para **Pronto** e a issue fecha.

### Se a `main` andou enquanto você trabalhava
```bash
git checkout main && git pull
git checkout sua-branch
git merge main
# se der conflito: resolva no VS Code, depois git add . && git commit
git push
```

---

## 5. Convenções de código

### Nomes
- **Tudo em inglês** no código: entidades, campos, funções, variáveis, arquivos.
- **Entidades CDS no plural**, em PascalCase: `Players`, `Events`, `Charges` (não `Player`).
- Campos e funções em camelCase: `firstName`, `calculateRating()`.
- **Textos que o usuário vê ficam em português, e sempre no i18n.**

### Regras que valem para todo PR
Elas vêm do checklist do PR, mas vale entender o porquê:

- **Nada de texto fixo na view.** Todo texto vai para `i18n.properties`, para facilitar mudanças e traduções.
- **Regra de negócio sempre no backend.** A tela pode validar para ajudar o usuário, mas quem garante a regra é o serviço CAP. A tela pode ser burlada, o backend não.
- **Nada de valor fixo no código** quando for algo que o grupo pode querer mudar (preço, número de vagas, prazos). Use `settings.get()`.
- **Anotações CDS revisadas:** labels, `LineItem`, `FieldGroup` e `ValueList`. É a partir delas que os Smart Controls montam tabelas e formulários.
- **Teste** sempre que houver regra de negócio.
- **Teste no celular.** A maioria do grupo vai usar o app pelo celular.

---

## 6. Definição de pronto

Uma issue só está **pronta** quando:

- [ ] O PR foi revisado e aprovado
- [ ] Tem teste, quando há regra de negócio
- [ ] Está publicado no Render
- [ ] Foi mostrado na demo semanal

---

## 7. Quando travar

- **Regra dos 30 minutos:** travou por mais de 30 minutos no mesmo problema? Pergunte. Ninguém ganha nada com você sofrendo sozinho por horas.
- Ao perguntar, mande: **o que você tentou fazer, o que esperava, o que aconteceu** (mensagem de erro completa ou print).
- Dúvida sobre uma issue → comente na própria issue, assim fica registrado.
- Dúvida rápida → chame o Mafra direto.

### Links úteis
- CAP: https://cap.cloud.sap/docs/
- SAPUI5 (API e exemplos): https://sapui5.hana.ondemand.com/
- Conventional Commits: https://www.conventionalcommits.org/pt-br/

---

**Primeira tarefa sugerida:** issue **#1, Criar repositório e estrutura inicial do projeto CAP** (nível iniciante). Bom jogo! ⚽
