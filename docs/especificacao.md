# Especificação Técnica — App "Futebol de Terça"

- **Stack:** SAP CAP (Node.js) · SAPUI5 Fiori **freestyle** com **Smart Controls** (OData V2) · PostgreSQL · Render · GitHub
- **Versão:** 1.4 (versão para início do desenvolvimento) · **Data:** 13/11/2026
- **Mudança da v0.2:** frontend deixa de usar Fiori Elements e passa a ser Fiori freestyle (XML views + controllers próprios), com smart controls para toda exibição e entrada de dados.
- **Mudança da v0.3:** onde não há smart control adequado, a interface usa controles visuais do SAPUI5 (cards, tiles, avatares, estrelas, barras de progresso, ilustrações) para ficar mais amigável, principalmente no celular. Ver decisão D2 e seção 6.0.1.
- **Mudança da v1.0:** decisões fechadas (seção 1.5): plano gratuito, e-mail via API do Gmail, jogo e churrasco independentes, **convidados** trazidos por jogadores, jogador avulso com diária, votação só de quem confirmou, inadimplência só com lembrete.
- **Mudança da v1.1:** nova **Central de Configurações** (seção 7.0): tudo que pode variar virou parâmetro editável pelo admin, inclusive bloqueio por inadimplência, multas e faltas (desligados por padrão).
- **Mudança da v1.2:** banco definido como **Render Postgres Free**, com rotina de renovação a cada 30 dias (seção 9.5).
- **Mudança da v1.3:** **cadastro de eventos genérico** (seção 7.0.1): tipos configuráveis (jogo, churrasco, confraternização de fim de ano, outros), valor por pessoa com faixas de preço (jogador, convidado, criança), rateio de custo total ou gratuito, eventos independentes ou vinculados ao jogo.
- **Mudança da v1.4:** **dia do jogo** com check-in e **sorteio de times** equilibrado e configurável (seção 7.0.2); **artilharia e assistências** lançadas pelos jogadores, com rankings (seção 7.0.3).

---

## 1. Visão geral

### 1.1 Objetivo
Organizar o futebol semanal de terça-feira: presença no jogo e no churrasco, mensalidades e pagamentos via PIX, avaliação entre jogadores (rating) e administração do grupo.

### 1.2 Escopo
| App | Público | Funções principais |
|---|---|---|
| **App do Jogador** | Todos os jogadores ativos | Login, recuperação de senha, home com perfil e rating, votação pós-jogo, financeiro (consultar e pagar via PIX), confirmação de jogo e de churrasco, notificações |
| **App do Administrador** | Jogadores com papel `Admin` | Cadastro e convite de jogadores, eventos (jogo/churrasco), chaves PIX, aprovação de pagamentos, redefinição de senha, promoção a admin, painel e funcionalidades extras (seção 8) |

### 1.3 Premissas e restrições
- Backend 100% **SAP CAP Node.js** (`@sap/cds` 9.x) com **`@cap-js/postgres`**.
- Frontend em **SAPUI5 Fiori freestyle**: um app UI5 por papel (Jogador e Admin), cada um com XML views, controllers, router e i18n próprios. **Nada de Fiori Elements** (sem templates List Report/Object Page/Overview Page).
- Toda exibição e entrada de dados usa **Smart Controls** (`sap.ui.comp`): `SmartFilterBar`, `SmartTable`, `SmartForm`, `SmartField`, `SmartChart`, `SmartVariantManagement`, `SmartLink`, `SmartMultiInput`. Os smart controls são guiados por anotações CDS (LineItem, SelectionFields, FieldGroup, ValueList etc.), então o backend continua anotado.
- Hospedagem no **Render** (Web Service + PostgreSQL gerenciado). **Sem SAP BTP** → sem XSUAA, sem Launchpad Service, sem Destination/Alert Notification. Autenticação, e-mail e agendamentos são resolvidos dentro da própria app (seção 3).
- Código-fonte em **repositório GitHub** com CI/CD (seção 9).

### 1.4 Decisões de arquitetura que precisam do seu OK

**D1 — Smart controls exigem OData V2.**
Os smart controls (`sap.ui.comp`) só funcionam com `sap.ui.model.odata.v2.ODataModel`. O CAP expõe OData V4 nativamente; para V2 usamos o adapter da comunidade **`@cap-js-community/odata-v2-adapter`**, que publica os mesmos serviços em `/odata/v2/...`. A biblioteca `sap.ui.comp` está estável, mas a SAP não a evolui mais (o sucessor é `sap.ui.mdc`). Para um app pessoal isso não é problema, só não espere recursos novos.

**D2 — Smart controls para dados, controles visuais do SAPUI5 para o resto (aprovado).**
Smart controls cobrem **dados tabulares e formulários** (filtro, tabela, formulário, campo, gráfico, variantes). Não existem smart controls para layout, navegação ou elementos visuais. Regra:
- **Listas, filtros e formulários de cadastro/edição → sempre smart control** (`SmartFilterBar`, `SmartTable`, `SmartForm`, `SmartField`, `SmartChart`, `SmartVariantManagement`). Nenhum `sap.m.Table` ou `sap.m.Input` solto para dados de negócio.
- **Layout e navegação → `sap.m` / `sap.f` / `sap.tnt` / `sap.uxap`:** `tnt.ToolPage`, `tnt.ToolHeader`, `tnt.SideNavigation`, `f.DynamicPage`, `uxap.ObjectPageLayout`, `f.GridContainer`, `Dialog`, `Toolbar`, `IconTabBar`, `Wizard`.
- **Elementos visuais amigáveis, liberados onde smart control não serve ou deixa a tela "corporativa" demais** (detalhes na seção 6.0.1): `f.Card` com cabeçalhos numéricos, `GenericTile` + `NumericContent`/`TileContent`, `f.Avatar`/`AvatarGroup`, `RatingIndicator`, `ObjectStatus`/`GenericTag`, `ProgressIndicator`/`RadialMicroChart` (`sap.suite.ui.microchart`), `IllustratedMessage`, `MessageStrip`, `Image` (QR Code), `upload.UploadSet`, `SegmentedButton`, `Input type=Password`.
- Esses controles **leem do mesmo ODataModel V2** (binding normal), então não há modelo paralelo nem regra de negócio no frontend.

**D2.1 — Um app por papel, com menu lateral próprio.**
Cada app (Jogador e Admin) é um único componente UI5 freestyle com:
- Rotas públicas: **Login**, **Esqueci a senha**, **Redefinir senha**, **Aceitar convite**.
- Rotas protegidas dentro de um `sap.tnt.ToolPage` + `SideNavigation` (menu à esquerda). Cada item do menu é uma rota/view do mesmo app, sem `ComponentContainer` e sem Launchpad. A navegação fica mais simples do que na v0.1.
- Um guard no router (`attachBeforeRouteMatched`) checa a sessão (`GET /auth/me`) e manda para o Login se não houver sessão.

**D2.2 — Sem draft.**
O draft do CAP foi pensado para o Fiori Elements e é trabalhoso de usar em freestyle V2. As edições usam o modo editável do `SmartForm`/`SmartTable` com **grupos deferidos** do ODataModel (`setDeferredGroups` + `submitChanges`), e as operações de negócio são **actions/function imports** (`oModel.callFunction`). Validações ficam no backend (`srv.before('UPDATE', ...)`).

**D3 — "Enviar a senha por e-mail".**
Senhas serão armazenadas com **hash (bcrypt)**, então é impossível (e inseguro) reenviar a senha original. Proposta: o fluxo "Esqueci a senha" valida e-mail + CPF + data de nascimento e envia um **link de redefinição** (token de uso único, expira em 30 min). Alternativa aceitável: enviar **senha temporária** com troca obrigatória no próximo login. **Decidido: link de redefinição.**

### 1.5 Decisões fechadas
| # | Tema | Decisão |
|---|---|---|
| 1 | Recuperação de senha | Link de redefinição por e-mail (token único, 30 min) |
| 2 | Hospedagem | **Plano gratuito.** Web Service Free + **Render Postgres Free**, com rotina de renovação do banco antes dos 30 dias (seção 9.5). Consequências tratadas nas seções 3.3, 3.6, 9.4 e 9.5 |
| 3 | E-mail | **API do Gmail (HTTPS) com uma conta Gmail do grupo**; plano B: Brevo (API, gratuito). SMTP não funciona no plano gratuito do Render |
| 4 | Jogo x churrasco | Eventos **independentes**: dá para ir só ao jogo, só ao churrasco ou aos dois. Cada jogador pode **levar convidados** para o jogo e/ou o churrasco |
| 5 | Quem vota | Apenas quem **confirmou** presença no jogo (convidados não votam nem são votados) |
| 6 | Votação | Anônima, janela de 48h, rating exibido após 3 jogos avaliados, craque da partida opcional |
| 7 | Avulso | Existe jogador avulso (com login) que **paga diária por jogo** confirmado |
| 8 | Inadimplência | **Apenas lembretes por padrão.** Bloqueio, multa e suspensão existem como **parâmetros desligados** na Central de Configurações |
| 10 | Eventos | Tipos de evento cadastráveis pelo admin; cobrança por pessoa (com faixas), rateio ou gratuita; evento social independente ou vinculado ao jogo (seção 7.0.1) |
| 11 | Sorteio de times | No dia do jogo, só entre quem fez check-in; modo equilibrado por padrão (força = rating), jogadores por time configuráveis, variedade e transparência (seção 7.0.2) |
| 12 | Artilharia/assistências | Lançadas pelo próprio jogador, assistência creditada a quem foi indicado, contestação em 24h; rankings por temporada (seção 7.0.3) |
| 9 | Configurabilidade | Toda regra que pode variar é parâmetro na Central de Configurações (seção 7.0), sem valor fixo no código |

---

## 2. Benchmark de apps similares e soluções propostas

Apps analisados: **Chega+** (o mais popular do segmento no Brasil, anuncia mais de 1 milhão de usuários), **Pelada+**, **FutMatch**, **Futebol Society**, **Sorteio de Times – Futebol**, **Futbora**.

| Padrão observado no mercado | Como os concorrentes fazem | O que propomos para o nosso app |
|---|---|---|
| Confirmação de presença | Lista com limite de vagas, separação goleiro/linha e **lista de espera automática** (Chega+) | Vagas por evento (linha/goleiro), lista de espera com promoção automática quando alguém desiste, prazo de confirmação |
| Mensalistas x convidados | Chega+ gerencia mensalistas e convidados separadamente | Tipo de jogador `MENSALISTA` / `AVULSO` (avulso paga diária por jogo) + **convidados** trazidos por qualquer jogador, para o jogo ou o churrasco |
| Churrasco pós-jogo | Chega+ gerencia confirmação, tipo de pagamento e custos do churrasco | Evento `CHURRASCO` vinculado ao jogo do dia, com PIX próprio e prestação de contas |
| Sorteio equilibrado de times | Recurso central em praticamente todos (por nota, posição e ordem de chegada) | Sorteio usando o **rating** do nosso sistema de votação + posição (seção 8) |
| Estatísticas e ranking | Gols, assistências, presença, artilheiro, "garçom" | Registro de gols/assistências e **craque da partida** na votação |
| Controle financeiro | Receitas, despesas, carteira por jogador, "quem pagou ou não" | Cobranças, aprovação de comprovante, **caixa do grupo** com despesas (quadra, bola, coletes) |
| Agenda | Avaliações de usuários do Chega+ pedem sincronia com o calendário do celular | Botão "Adicionar ao calendário" (.ics) em cada evento |
| Convite | Link via WhatsApp | Convite por e-mail (requisito) + texto pronto para WhatsApp |
| Monetização | Sorteio e recursos bloqueados atrás de assinatura geram reclamações | App próprio, sem paywall |

---

## 3. Arquitetura

### 3.1 Visão de componentes
```
 Navegador (desktop/mobile)
 ├─ /player  → App freestyle Jogador (login + ToolPage + views com smart controls)
 └─ /admin   → App freestyle Admin   (login + ToolPage + views com smart controls)
        │  OData V2 (/odata/v2/...)  — cookie de sessão HttpOnly
        ▼
 Render Web Service (Node 20+)
 ├─ CAP server (cds-serve)
 │   ├─ AuthService   (anônimo)      login, esqueci senha, convite
 │   ├─ PlayerService (@requires Player)
 │   ├─ AdminService  (@requires Admin)
 │   └─ JobsService   (protegido por segredo) lembretes, cobranças, votação
 ├─ odata-v2-adapter
 ├─ Middleware de autenticação JWT (custom auth)
 └─ libs: pix.js (BR Code + QR), mailer.js, ics.js
        │
        ├─ Render PostgreSQL (@cap-js/postgres)
        ├─ Gmail API (HTTPS, OAuth2) — plano B: Brevo API
        └─ GitHub Actions (cron) → chama JobsService
```
Um único Web Service serve backend e os apps UI5 estáticos (pasta `app/`), sem CORS.

### 3.2 Autenticação e autorização
- `cds.requires.auth = { kind: "custom", impl: "srv/lib/auth.js" }`.
- `AuthService.login(email, senha)` valida o hash bcrypt e grava um **JWT em cookie `HttpOnly; Secure; SameSite=Strict`** (expira em 7 dias, com refresh deslizante). Cookie é melhor que header Bearer aqui porque os smart controls disparam requests OData sozinhos (metadata, $batch, value helps), e o cookie vai junto automaticamente, sem precisar injetar headers.
- Endpoint auxiliar `GET /auth/me` (fora do OData) devolve `{ id, nome, isAdmin, mustChangePassword }` para o guard de rotas do app.
- O middleware lê o cookie e cria `req.user = new cds.User({ id: playerId, roles: ['Player'] (+ 'Admin') })`.
- Autorização via `@requires` / `@restrict` com `where: 'player_ID = $user'` (cada jogador só vê os próprios dados).
- Proteções: rate limit no login e no esqueci-senha (`express-rate-limit`), bloqueio temporário após 5 tentativas, `helmet`, mensagens genéricas ("se os dados conferirem, você receberá um e-mail") para não revelar quais e-mails existem.
- Jogador com `status = INATIVO` não autentica.

### 3.3 E-mail (gratuito)
- **Restrição:** desde setembro/2025 o Web Service gratuito do Render **bloqueia as portas SMTP (25, 465 e 587)**. Portanto `nodemailer` + `smtp.gmail.com` com senha de app **não funciona** no plano gratuito. Todo envio vai por **API HTTPS (porta 443)**.
- **Opção escolhida: API do Gmail** com uma conta Gmail dedicada ao grupo (ex.: `futeboldeterca.xxx@gmail.com`; evite usar a conta pessoal). Custo zero, limite de ~500 e-mails/dia de uma conta Gmail comum (sobra muito) e boa entrega, porque o e-mail sai pelos servidores do próprio Google.
  - Configuração única: projeto no Google Cloud → ativar a Gmail API → tela de consentimento OAuth (tipo *Externo*, com a própria conta do grupo como usuária) → **publicar em "Em produção"** (em "Teste" o refresh token expira em 7 dias) → criar cliente OAuth → gerar o **refresh token** uma vez (OAuth Playground) com o escopo `https://www.googleapis.com/auth/gmail.send`.
  - Variáveis no Render: `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`, `MAIL_FROM`.
  - Envio com a lib `googleapis` (`gmail.users.messages.send`, mensagem MIME em base64url).
- **Plano B: Brevo** (gratuito, 300 e-mails/dia, API HTTPS). Basta verificar o mesmo Gmail como remetente, sem domínio próprio. Como o e-mail sai de servidores da Brevo com remetente `@gmail.com`, ele tem mais chance de cair no spam.
- `srv/lib/mailer.js` com interface única (`send({ to, subject, html })`) e implementação escolhida por `MAIL_PROVIDER=gmail|brevo|console` (`console` em desenvolvimento, só loga).
- Templates: convite, redefinição de senha, novo evento (pedido de confirmação), lembrete de confirmação, cobrança gerada, pagamento aprovado/rejeitado, votação aberta.

### 3.4 Notificações
Sem SAP Launchpad, não existe o Notification Center do Fiori. Proposta em camadas:
1. **Notificações no app** (entidade `Notifications`) com contador no header do ToolPage (`sap.m.Button` com badge) e lista no menu.
2. **E-mail** para eventos importantes (novo jogo, cobrança, aprovação).
3. **(Fase 2) Web Push** com os apps instaláveis como PWA (service worker + VAPID, lib `web-push`).
4. Botão "Compartilhar no WhatsApp" com texto pronto (deep link `wa.me`), sem integração paga.

### 3.5 PIX
- O admin cadastra chaves PIX (`PixKeys`) e escolhe qual chave usar para **mensalidade** (configuração geral) e para **cada churrasco** (no evento).
- Para cada cobrança, o backend gera o **BR Code estático "copia e cola"** (padrão EMV do Banco Central: chave, valor, nome do recebedor, cidade, txid e CRC16) em `srv/lib/pix.js`, e uma imagem de **QR Code** (lib `qrcode`) exposta por endpoint `GET /pix/qrcode/:chargeId.png`.
- Fluxo: jogador paga no app do banco → anexa o **comprovante** → status `INFORMADO` → admin aprova/rejeita.
- **Fase 2 (opcional):** integrar um PSP com PIX dinâmico e webhook (ex.: Mercado Pago, Efí, Asaas) para baixa automática, eliminando a aprovação manual.

### 3.6 Jobs agendados
O Web Service gratuito do Render dorme após 15 min sem tráfego e leva cerca de 1 min para acordar, então `node-cron` interno não é confiável. Proposta: **GitHub Actions com `schedule` de hora em hora** chamando `POST /jobs/tick` com header `X-Job-Secret` (gratuito). O backend decide quais jobs executar conforme os horários e switches da Central de Configurações (seção 7.0). Alternativa paga: Render Cron Job.

**Manter acordado (keep-alive):** um ping em `GET /health` a cada 14 min (cron-job.org ou UptimeRobot, gratuitos) evita a espera de ~1 min na hora de confirmar presença. Um serviço sempre ligado consome ~744 h/mês, dentro das 750 h gratuitas do workspace, **desde que seja o único serviço gratuito**. Se preferir economizar horas, ping só das 07h às 24h.

| Job | Quando roda (configurável) | O que faz |
|---|---|---|
| `gerarAgenda` | Diário | Cria/publica os próximos jogos (e churrascos) conforme a recorrência configurada |
| `gerarMensalidades` | Dia configurado do mês | Cria cobranças `MENSALIDADE` para mensalistas ativos |
| `lembretesVencimento` | Diário, respeitando dias antes/depois e horário silencioso | Avisa cobranças vencendo / vencidas |
| `lembreteConfirmacao` | X horas antes do prazo | Lembra quem não respondeu ao jogo de terça |
| `fecharConfirmacoes` | No prazo do evento | Fecha lista, promove lista de espera (jogadores do grupo primeiro, depois convidados) e gera as cobranças dos convidados promovidos |
| `abrirVotacao` / `encerrarVotacao` | X horas após o jogo / fim da janela |
| `aplicarRegrasInadimplencia` | Diário (só se o bloqueio ou a multa estiverem ligados) | Marca bloqueios e gera multas conforme os parâmetros |
| `limparComprovantes` | Mensal | Apaga comprovantes além da retenção configurada | Controla a janela de votação e recalcula ratings |

---

## 4. Modelo de dados (CDS)

Namespace `futebol`. Todas as entidades usam `cuid` e `managed` (`createdAt`, `createdBy`, `modifiedAt`, `modifiedBy`).

```cds
namespace futebol;
using { cuid, managed, sap.common.CodeList } from '@sap/cds/common';

// ---------- Code lists ----------
entity PlayerStatus     : CodeList { key code : String(10); } // CONVIDADO (convite pendente), ATIVO, INATIVO
entity PlayerTypes      : CodeList { key code : String(10); } // MENSALISTA, AVULSO
entity Positions        : CodeList { key code : String(10); } // GOLEIRO, LINHA
entity FieldRoles       : CodeList { key code : String(10); } // DEFESA, MEIO, ATAQUE (posição preferida na linha, opcional)
entity DrawModes        : CodeList { key code : String(12); } // EQUILIBRADO, ALEATORIO, ORDEM_CHEGADA, CAPITAES
entity GoalStatus       : CodeList { key code : String(10); } // VALIDO, PENDENTE, CONTESTADO, REJEITADO
entity EventCategories  : CodeList { key code : String(10); } // JOGO, SOCIAL
entity ChargeModes      : CodeList { key code : String(12); } // POR_PESSOA, RATEIO, GRATUITO
entity EventStatus      : CodeList { key code : String(10); } // RASCUNHO, ABERTO, FECHADO, REALIZADO, CANCELADO
entity AttendanceStatus : CodeList { key code : String(10); } // PENDENTE, CONFIRMADO, RECUSADO, ESPERA
entity ChargeTypes      : CodeList { key code : String(12); } // MENSALIDADE, DIARIA, EVENTO (churrasco, fim de ano...), OUTRO
entity ChargeStatus     : CodeList { key code : String(10); } // PENDENTE, INFORMADO, APROVADO, REJEITADO, CANCELADO
entity PixKeyTypes      : CodeList { key code : String(10); } // CPF, CNPJ, EMAIL, TELEFONE, ALEATORIA

// ---------- Jogadores ----------
entity Players : cuid, managed {
  nomeCompleto       : String(120) not null;
  apelido            : String(40);
  email              : String(120) not null;   // unique
  cpf                : String(11)  not null;   // unique, validado (dígitos verificadores)
  dataNascimento     : Date        not null;
  telefone           : String(20);
  foto               : LargeBinary @Core.MediaType: fotoMimeType;
  fotoMimeType       : String @Core.IsMediaType;
  posicao            : Association to Positions;
  posicaoLinha       : Association to FieldRoles;   // preferida: defesa, meio, ataque (opcional)
  notaInicial        : Decimal(3,2);                 // força inicial do novato, definida pelo admin
  tipo               : Association to PlayerTypes default 'MENSALISTA';
  status             : Association to PlayerStatus default 'CONVIDADO';
  isAdmin            : Boolean default false;
  senhaHash          : String(100) @Core.Computed;   // nunca exposto
  mustChangePassword : Boolean default false;
  tentativasLogin    : Integer default 0;
  bloqueadoAte       : Timestamp;
  aceiteLgpdEm       : Timestamp;
  rating             : Decimal(3,2) @Core.Computed;  // média calculada (seção 5.4)
  faltas             : Integer @Core.Computed;       // usado só se registrarFaltas = true
  suspensoAte        : Date;                         // usado só se suspenderPorFaltas = true
  termosVersaoAceita : Integer;
  totalJogos         : Integer      @Core.Computed;
  attendances        : Association to many Attendances on attendances.player = $self;
  charges            : Association to many Charges     on charges.player     = $self;
}

entity Invitations : cuid, managed {
  player     : Association to Players;
  tokenHash  : String(100);
  expiraEm   : Timestamp;
  aceitoEm   : Timestamp;
}

entity PasswordResets : cuid {
  player    : Association to Players;
  tokenHash : String(100);
  expiraEm  : Timestamp;
  usadoEm   : Timestamp;
}

// ---------- Configuração ----------
entity PixKeys : cuid, managed {
  descricao     : String(60);
  tipoChave     : Association to PixKeyTypes;
  chave         : String(77);
  nomeRecebedor : String(25);   // limite do BR Code
  cidade        : String(15);   // limite do BR Code
  ativo         : Boolean default true;
}

@cds.singleton   // uma única linha; campos agrupados por @UI.FieldGroup (ver seção 7.0)
entity Settings : managed {
  key ID : Integer default 1;
  // Geral
  nomeGrupo : String(60); logo : LargeBinary @Core.MediaType: logoMimeType; logoMimeType : String @Core.IsMediaType;
  corDestaque : String(7); diaSemanaPadrao : Integer; horaPadrao : Time; duracaoMin : Integer; localPadrao : String(120);
  // Agenda automática
  agendaAutomatica : Boolean; semanasAFrente : Integer; publicarAutomatico : Boolean; churrascoComJogo : Boolean;
  // Presença
  vagasLinhaPadrao : Integer; vagasGoleiroPadrao : Integer; prazoConfirmacaoHoras : Integer;
  permitirConfirmarAposPrazo : Boolean; listaEsperaAutomatica : Boolean; permitirDesistirAposPrazo : Boolean;
  permitirSoChurrasco : Boolean; sugerirChurrasco : Boolean;
  // Convidados
  convidadosJogo : Boolean; convidadosChurrasco : Boolean; maxConvidadosPorJogador : Integer;
  convidadosSoAposPrazo : Boolean; valorDiariaConvidado : Decimal(9,2); valorChurrascoConvidado : Decimal(9,2);
  cobrancaNoAnfitriao : Boolean;
  // Financeiro
  valorMensalidade : Decimal(9,2); valorDiariaAvulso : Decimal(9,2); valorChurrascoPadrao : Decimal(9,2);
  diaVencimento : Integer; gerarMensalidadesAuto : Boolean; diaGerarMensalidade : Integer; prazoPagamentoDias : Integer;
  pixMensalidade : Association to PixKeys; pixDiaria : Association to PixKeys; pixChurrascoPadrao : Association to PixKeys;
  exigirComprovante : Boolean; retencaoComprovantesMeses : Integer;
  // Inadimplência (bloqueio/multa desligados por padrão)
  lembretesVencimento : Boolean; lembrarDiasAntes : Integer; lembrarCadaDiasDepois : Integer;
  bloquearInadimplente : Boolean; toleranciaBloqueioDias : Integer; valorMinimoBloqueio : Decimal(9,2);
  bloquearChurrasco : Boolean; bloquearVotacao : Boolean;
  multaAtraso : Boolean; multaAtrasoTipo : String(1) /* P=% V=valor */; multaAtrasoValor : Decimal(9,2);
  mostrarPendenciasGrupo : Boolean;
  // Faltas
  registrarFaltas : Boolean; prazoDesistenciaSemFaltaHoras : Integer; multaFalta : Boolean; valorMultaFalta : Decimal(9,2);
  suspenderPorFaltas : Boolean; faltasParaSuspender : Integer; jogosSuspensao : Integer;
  // Votação
  votacaoHabilitada : Boolean; abrirVotacaoHorasApos : Integer; janelaVotacaoHoras : Integer; votosAnonimos : Boolean;
  craqueHabilitado : Boolean; minJogosRating : Integer; metodoRating : String(10) /* MEDIA_MEDIAS, SIMPLES, ULTIMOS */;
  ultimosNJogos : Integer; ratingVisibilidade : String(10) /* TODOS, PROPRIO */;
  // Dia do jogo / sorteio de times
  quemSorteia : String(12) /* ADMIN, ORGANIZADOR, CONFIRMADOS */; checkinProprio : Boolean;
  checkinMinAntes : Integer; checkinMinDepois : Integer;
  modoSorteio : Association to DrawModes; jogadoresLinhaPorTime : Integer; goleiroPorTime : Integer;
  numTimesAutomatico : Boolean; numTimesFixo : Integer; sobraJogadores : String(12) /* TIME_ESPERA, DISTRIBUIR */;
  semGoleiro : String(12) /* RODIZIO, SEM_GOLEIRO */; coresColetes : String(200);
  ratingPadraoNovato : Decimal(3,2); ultimosNJogosForca : Integer; pesoEstatisticas : Decimal(3,2);
  equilibrarPosicoes : Boolean; evitarRepetirDuplas : Boolean; jogosMemoriaDuplas : Integer;
  solucoesSorteio : Integer; toleranciaSorteioPct : Decimal(5,2); atrasadoVaiPara : String(12) /* ESPERA, MAIS_FRACO */;
  // Artilharia e assistências
  estatisticasHabilitadas : Boolean; quemLancaGols : String(12) /* PROPRIO, PARTICIPANTES, ORGANIZADOR */;
  validacaoGols : String(12) /* AUTOMATICA, COLEGA, ADMIN */; horasContestacao : Integer; maxGolsPorJogo : Integer;
  registrarGolContra : Boolean; registrarPartidas : Boolean; inicioTemporada : Date; desempateRanking : String(30);
  // Notificações
  horasLembreteConfirmacao : Integer; silencioInicio : Time; silencioFim : Time;
  // Segurança
  maxTentativasLogin : Integer; minutosBloqueioLogin : Integer; diasValidadeConvite : Integer;
  minutosValidadeReset : Integer; diasSessao : Integer; tamanhoMinSenha : Integer;
  // Privacidade
  termosTexto : LargeString; termosVersao : Integer; exigirNovoAceite : Boolean;
  // Infra (somente leitura na tela)
  dbCriadoEm : Date;
}
// Os padrões ficam em db/data/futebol-Settings.csv (seção 7.0), não no código.

entity NotificationRules : cuid {   // matriz tipo de aviso x canal
  tipo   : String(30);   // NOVO_EVENTO, LEMBRETE_CONFIRMACAO, COBRANCA, PAGAMENTO_APROVADO, VOTACAO_ABERTA, PROMOVIDO_ESPERA...
  inApp  : Boolean default true;
  email  : Boolean default false;
}

entity EmailTemplates : cuid, managed {
  tipo    : String(30);
  assunto : String(150);
  corpo   : LargeString;   // HTML com variáveis {{nome}}, {{data}}, {{valor}}, {{link}}
}

// ---------- Eventos ----------
// Tipos de evento cadastráveis pelo admin (seção 7.0.1)
entity EventTypes : cuid, managed {
  nome                   : String(60) not null;   // "Jogo de terça", "Churrasco", "Confraternização de fim de ano"
  categoria              : Association to EventCategories not null; // JOGO tem vagas linha/goleiro e votação
  icone                  : String(40);            // sap-icon://...
  cor                    : String(7);
  modoCobrancaPadrao     : Association to ChargeModes default 'POR_PESSOA';
  pixPadrao              : Association to PixKeys;
  permiteConvidados      : Boolean default true;
  maxConvidadosPadrao    : Integer;
  controlaVagas          : Boolean default false;
  vagasPadrao            : Integer;
  prazoConfirmacaoHoras  : Integer;
  prazoPagamentoDias     : Integer;
  ativo                  : Boolean default true;
  precosPadrao           : Composition of many EventTypePrices on precosPadrao.tipo = $self;
}
entity EventTypePrices : cuid {        // faixas padrão do tipo
  tipo      : Association to EventTypes;
  descricao : String(40);              // Jogador, Convidado, Criança até 12...
  valor     : Decimal(9,2);
  paraConvidado : Boolean default false;
  ordem     : Integer;
}

entity Events : cuid, managed {
  tipo              : Association to EventTypes not null;
  titulo            : String(80);
  descricao         : String(1000);
  capa              : LargeBinary @Core.MediaType: capaMimeType;
  capaMimeType      : String @Core.IsMediaType;
  data              : Date not null;
  horaInicio        : Time;
  horaFim           : Time;
  local             : String(120);
  status            : Association to EventStatus default 'RASCUNHO';
  vagasLinha        : Integer;
  vagasGoleiro      : Integer;
  prazoConfirmacao  : Timestamp;
  vagas             : Integer;                 // eventos sociais com limite (opcional)
  modoCobranca      : Association to ChargeModes;   // copiado do tipo, editável
  custoTotal        : Decimal(9,2);            // usado no RATEIO
  valorRateio       : Decimal(9,2) @Core.Computed;  // calculado ao fechar a lista
  pixKey            : Association to PixKeys;  // chave do evento (copiada do tipo)
  prazoPagamento    : Date;
  maxConvidados     : Integer;
  publico           : String(12) default 'TODOS';   // TODOS, MENSALISTAS, SELECIONADOS
  organizador       : Association to Players;  // organizador do dia (check-in e sorteio)
  timesPublicados   : Boolean default false;
  jogo              : Association to Events;   // vínculo opcional com o jogo do dia
  eventosVinculados : Association to many Events on eventosVinculados.jogo = $self;
  precos            : Composition of many EventPrices on precos.event = $self;
  votacaoAbertaAte  : Timestamp;
  placar            : String(20);
  observacoes       : String(500);
  attendances       : Composition of many Attendances on attendances.event = $self;
  charges           : Association to many Charges on charges.event = $self;
  votes             : Association to many Votes   on votes.event   = $self;
}

entity Attendances : cuid, managed {
  event        : Association to Events not null;
  player       : Association to Players;          // jogador cadastrado (nulo se for convidado)
  guest        : Association to Guests;           // convidado (nulo se for jogador)
  status       : Association to AttendanceStatus default 'PENDENTE';
  posicao      : Association to Positions;        // goleiro/linha (para vagas)
  posicaoFila  : Integer;          // lista de espera
  respondidoEm : Timestamp;
  presente     : Boolean;          // check-in no dia (opcional, só estatística)
  ordemChegada : Integer;          // check-in no dia
  checkinEm    : Timestamp;
  team         : Association to Teams;   // time do sorteio publicado
  goleiroRodizio : Boolean default false;
  // gols/assistências: calculados a partir de Goals (view PlayerStats)
}
// unique (event, player) e (event, guest); exatamente um de player/guest preenchido
// + priceTier : Association to EventPrices  (faixa escolhida: Jogador, Convidado, Criança...)

entity EventPrices : cuid {           // faixas de preço do evento (copiadas do tipo, editáveis)
  event     : Association to Events;
  descricao : String(40);
  valor     : Decimal(9,2);
  paraConvidado : Boolean default false;
  ordem     : Integer;
}

// ---------- Convidados ----------
entity Guests : cuid, managed {
  nome          : String(120) not null;
  telefone      : String(20);
  convidadoPor  : Association to Players not null; // responsável pela cobrança
  posicao       : Association to Positions;
}

// ---------- Dia do jogo: sorteio ----------
entity Teams : cuid {
  event      : Association to Events;
  numero     : Integer;            // 1, 2, 3 (3 = time de espera, se houver)
  nome       : String(30);         // "Time Laranja"
  cor        : String(20);         // cor do colete
  forcaTotal : Decimal(6,2);
  forcaMedia : Decimal(4,2);
  espera     : Boolean default false;
  members    : Association to many Attendances on members.team = $self;
}

entity DrawLogs : cuid, managed {
  event          : Association to Events;
  numeroSorteio  : Integer;        // 1º, 2º... (resorteios ficam visíveis)
  modo           : Association to DrawModes;
  seed           : String(32);
  parametros     : LargeString;    // JSON com a configuração usada
  resultado      : LargeString;    // JSON com times e forças
  equilibrioPct  : Decimal(5,2);
  publicado      : Boolean default false;
}

entity DrawConstraints : cuid, managed {  // restrições opcionais do sorteio
  playerA  : Association to Players;
  playerB  : Association to Players;
  tipo     : String(10);           // JUNTOS, SEPARADOS
  ativo    : Boolean default true;
}

entity Matches : cuid, managed {          // opcional: partidas da noite
  event    : Association to Events;
  numero   : Integer;
  timeA    : Association to Teams;
  timeB    : Association to Teams;
  golsA    : Integer;
  golsB    : Integer;
}

// ---------- Artilharia e assistências ----------
entity Goals : cuid, managed {
  event         : Association to Events not null;
  match         : Association to Matches;        // opcional
  scorer        : Association to Attendances;    // jogador ou convidado que marcou (nulo se gol contra)
  assistant     : Association to Attendances;    // quem deu a assistência (opcional)
  team          : Association to Teams;
  golContra     : Boolean default false;
  registradoPor : Association to Players;
  status        : Association to GoalStatus default 'VALIDO';
  contestadoPor : Association to Players;
  motivoContestacao : String(200);
}
// view PlayerStats: gols, assistências, G+A, jogos, média por jogo, por período/temporada

// ---------- Financeiro ----------
entity Charges : cuid, managed {
  player          : Association to Players not null;
  tipo            : Association to ChargeTypes not null;
  competencia     : String(7);       // AAAA-MM (mensalidade)
  event           : Association to Events; // churrasco / diária
  descricao       : String(120);
  valor           : Decimal(9,2) not null;
  vencimento      : Date;
  status          : Association to ChargeStatus default 'PENDENTE';
  pixKey          : Association to PixKeys;
  txid            : String(25);
  pixCopiaECola   : LargeString @Core.Computed;
  qrCodeUrl       : String @Core.Computed @UI.IsImageURL;
  comprovante     : LargeBinary @Core.MediaType: comprovanteMimeType;
  comprovanteMimeType : String @Core.IsMediaType;
  informadoEm     : Timestamp;
  aprovadoPor     : Association to Players;
  aprovadoEm      : Timestamp;
  motivoRejeicao  : String(200);
}

entity Expenses : cuid, managed {   // caixa do grupo (extra)
  data      : Date;
  descricao : String(120);
  categoria : String(30);   // QUADRA, BOLA, COLETES, CHURRASCO, OUTROS
  valor     : Decimal(9,2);
  event     : Association to Events;
  anexo     : LargeBinary @Core.MediaType: anexoMimeType;
  anexoMimeType : String @Core.IsMediaType;
}

// ---------- Votação ----------
entity Votes : cuid, managed {
  event      : Association to Events not null;
  voter      : Association to Players not null;
  votado     : Association to Players not null;
  nota       : Integer @assert.range: [1,5];
  craque     : Boolean default false; // "craque da partida" (1 por eleitor)
}
// unique (event, voter, votado); voter != votado

// ---------- Notificações / auditoria ----------
entity Notifications : cuid, managed {
  player : Association to Players;
  titulo : String(80);
  texto  : String(300);
  link   : String(200);   // rota interna do app (hash do router)
  lida   : Boolean default false;
}

entity AuditLog : cuid, managed {
  acao     : String(40);  // APROVAR_PAGAMENTO, RESET_SENHA, TORNAR_ADMIN...
  entidade : String(40);
  chave    : String(36);
  detalhe  : LargeString;
}
```

### 4.1 Views auxiliares
- `PlayerRatings`: média por jogador = **média das médias por partida** (cada jogo pesa igual, independentemente de quantos votaram).
- `LastMatch`: último evento `JOGO` com status `REALIZADO`.
- `Balance`: total arrecadado (cobranças aprovadas) − despesas = saldo do caixa.

---

## 5. Serviços CAP e regras de negócio

### 5.1 `AuthService` (anônimo) — `/odata/v2/auth`
| Operação | Regra |
|---|---|
| `action login(email, senha) returns { mustChangePassword, isAdmin }` | bcrypt.compare; até 5 tentativas → bloqueia 15 min; grava cookie JWT |
| `action logout()` | Limpa o cookie |
| `action esqueciSenha(email, cpf, dataNascimento)` | Se os 3 conferirem, gera token e envia link. Resposta **sempre** genérica |
| `action redefinirSenha(token, novaSenha)` | Token válido, não usado, não expirado. Política: mín. 8 caracteres |
| `action aceitarConvite(token, senha, aceiteLgpd)` | Ativa o jogador (`CONVIDADO → ATIVO`) |

### 5.2 `PlayerService` (`@requires: 'Player'`) — `/odata/v2/player`
| Entidade / ação | Detalhe |
|---|---|
| `Me` (projeção de `Players` filtrada por `$user`) | Somente leitura, exceto telefone/foto/apelido. CPF mascarado (`***.456.789-**`) |
| `action alterarSenha(atual, nova)` | |
| `MyEvents` (projeção de `Attendances` + evento) | Próximos eventos e respostas |
| `action confirmar()` / `recusar()` (bound em `MyEvents`) | Respeita prazo e vagas; sem vaga → `ESPERA` com posição na fila. Recusar libera vaga e promove o 1º da fila (com notificação) |
| `action confirmar(priceTierId)` em evento `SOCIAL` (churrasco, fim de ano...) | Independente do jogo. `POR_PESSOA`: cria `Charge` tipo `EVENTO` com o valor da faixa e o PIX do evento e devolve a cobrança. `RATEIO`: só registra; as cobranças nascem no `fecharLista()`. `GRATUITO`: sem cobrança. Recusar antes do evento cancela a cobrança pendente |
| `action confirmar()` em `JOGO` por jogador **avulso** | Cria `Charge` tipo `DIARIA` (valor `Settings.valorDiariaAvulso`, PIX `pixDiaria`). Recusar antes do prazo cancela a cobrança |
| `MyGuests` + `action adicionarConvidado(eventId, nome, telefone, posicao)` / `removerConvidado()` | Até `maxConvidadosPorJogador` por evento. Se `convidadosSoAposPrazo`, o convidado entra em `ESPERA` e só é promovido depois do prazo, se sobrar vaga (jogadores do grupo têm prioridade). Gera cobrança `DIARIA_CONVIDADO` ou `CHURRASCO_CONVIDADO` **no nome de quem convidou** quando a vaga é garantida |
| `MyCharges` | Cobranças do jogador, com `pixCopiaECola` e `qrCodeUrl` |
| `action informarPagamento(comprovante)` | `PENDENTE/REJEITADO → INFORMADO`; notifica admins |
| `BallotItems` (projeção da última partida para o eleitor) | Uma linha por jogador cadastrado que **confirmou** o jogo, menos o próprio (convidados ficam fora), com `nota` e `craque` editáveis enquanto a votação estiver aberta |
| `action cheguei()` (bound no jogo) | Check-in próprio dentro da janela configurada |
| `action sortearTimes()` / `trocarJogadores()` / `publicarTimes()` | Só para quem tem permissão de sortear (`quemSorteia`; organizador do dia) |
| `MyGoals` + `action lancarGol(eventId, assistenteId, golContra)` / `removerGol()` | Respeita `quemLancaGols`, janela, `maxGolsPorJogo` e `validacaoGols`; credita a assistência e notifica o assistente |
| `action contestarGol(goalId, motivo)` / `confirmarGol(goalId)` | Contestação até `horasContestacao`; confirmação por colega quando `validacaoGols = COLEGA` |
| `Rankings` (view `PlayerStats` com parâmetros de período) | Artilharia, assistências, G+A, craque, presença |
| `action enviarVotos()` | Valida que todos foram avaliados e grava os `Votes` de forma definitiva (depois disso, somente leitura) |
| `Notifications` | Do próprio jogador; `action marcarComoLida()` |

**Regras condicionadas à configuração (todas checadas no backend)**
- `confirmar()`: se `bloquearInadimplente` estiver ligado e o jogador tiver cobrança vencida há mais de `toleranciaBloqueioDias` e acima de `valorMinimoBloqueio`, a confirmação é recusada com a mensagem "Regularize suas pendências para confirmar" e um link para o Financeiro. O mesmo vale para churrasco/votação se `bloquearChurrasco`/`bloquearVotacao` estiverem ligados. Também é recusada se o jogador estiver com `suspensoAte` futuro (faltas).
- Prazo, vagas, lista de espera, convidados, só-churrasco e desistência seguem os switches do grupo **Presença/Convidados**.
- O app mostra antes do clique o motivo de um botão estar desabilitado (ex.: "Confirmação encerrada às 16h"), usando `PublicSettings` e campos calculados do evento.

**Regras de votação**
- Só vota e só é votado jogador cadastrado com `Attendance.status = CONFIRMADO` no jogo. Convidados não votam nem são votados.
- Janela: de `abrirVotacao` até `votacaoAbertaAte` (`janelaVotacaoHoras`, padrão 48h). Anonimato, craque, mínimo de jogos e método de cálculo vêm da configuração.
- Notas de 1 a 5, sem autovoto, um único "craque" por eleitor, votos **anônimos** (o admin vê só agregados).
- Ao encerrar: recalcula `Players.rating` e `totalJogos`. Jogador com menos de 3 jogos avaliados mostra "Em avaliação".

### 5.3 `AdminService` (`@requires: 'Admin'`) — `/odata/v2/admin`
| Entidade | Ações |
|---|---|
| `Players` | `convidar()`, `reenviarConvite()`, `redefinirSenha()` (gera senha temporária + `mustChangePassword` ou link), `tornarAdmin()`, `removerAdmin()` (bloqueia remover o último admin), `inativar()`, `reativar()` |
| `Events` (composição de `Attendances`) | `publicar()` (RASCUNHO → ABERTO, cria `Attendances` PENDENTE para todos os ativos e notifica), `criarEventoVinculado(tipoId)` (ex.: churrasco do dia), `duplicar()`, `fecharLista()` (no rateio: calcula `valorRateio` e gera as cobranças), `designarOrganizador(playerId)`, `checkin(attendanceId)`, `sortearTimes()` (gera `DrawLogs` + `Teams`, ainda não publicado), `trocarJogadores(a, b)`, `publicarTimes()`, `adicionarAtrasado(attendanceId)`, `registrarPartida()`, `corrigirGol()`, `encerrarTemporada()`, `abrirVotacao()`, `encerrarVotacao()`, `cancelar()` (notifica e cancela cobranças) |
| `Guests` | Admin também pode incluir convidados/avulsos diretamente no evento (`adicionarParticipante`), escolhendo o responsável pela cobrança ou marcando "sem cobrança" |
| `Charges` | `aprovar()`, `rejeitar(motivo)`, `cancelar()`, `gerarCobrancaAvulsa()`; ações em massa pela SmartTable (seleção múltipla) |
| `PixKeys`, `Settings` | CRUD / singleton |
| `Expenses` | CRUD (caixa) |
| `Dashboard*` | Views analíticas (inadimplência, presença, saldo) |

Toda ação de admin grava em `AuditLog`.

### 5.4 Cálculo do rating
```
notaPartida(j, e) = média das notas recebidas por j no evento e
rating(j)         = média de notaPartida(j, e) para todos os eventos e com votação encerrada
```
Exibido com 1 casa decimal e em estrelas (0–5).

---

## 6. App do Jogador (`app/player` — UI5 freestyle)

### 6.0 Padrões comuns aos dois apps
- **Modelo:** `ODataModel` V2 padrão no manifest, apontando para `/odata/v2/player` (ou `/odata/v2/admin`), com `defaultBindingMode: TwoWay`, `useBatch: true` e grupo deferido `changes` para edições.
- **Padrão de lista:** `SmartFilterBar` + `SmartTable` (`tableType="ResponsiveTable"`, `useVariantManagement`, `useExportToExcel`, `persistencyKey`) ligados pelo atributo `smartFilterId`. Colunas vêm de `@UI.LineItem`, filtros de `@UI.SelectionFields`, value helps de `@Common.ValueList`.
- **Padrão de detalhe:** `ObjectPageLayout` como container; cada seção tem um `SmartForm` (grupos vindos de `@UI.FieldGroup`, via `SmartForm` com `Group`/`GroupElement` + `SmartField`) ou uma `SmartTable` de itens.
- **Edição:** botão Editar/Salvar/Cancelar alterna `SmartForm.editable`; Salvar chama `oModel.submitChanges({ groupId: 'changes' })`; Cancelar chama `resetChanges()`.
- **Ações de negócio:** botões na toolbar da `SmartTable` (`customToolbar`) ou no header, que chamam `oModel.callFunction('/acao', { method: 'POST', urlParameters })`. As mensagens do backend (`sap-message`) aparecem num `MessagePopover` ligado ao `MessageManager`.
- **Status coloridos:** `SmartField` respeita `@UI.Criticality` / `@Common.Text` com `TextArrangement`.
- **Estrutura de código:** `BaseController` (getModel, navTo, callAction, tratamento de erro), `formatter.js`, `models.js`, `i18n_pt_BR.properties`.

### 6.0.1 Camada visual (identidade e componentes amigáveis)
**Tema e identidade**
- Tema **SAP Horizon** (`sap_horizon` claro / `sap_horizon_dark` escuro, seguindo a preferência do sistema via `sap-ui-theme=sap_horizon_auto` ou um switch no menu do avatar).
- Cor de destaque "verde gramado" (ex.: `#1B8A3A`) via **CSS custom properties** do Horizon (`--sapBrandColor`, `--sapButton_Emphasized_Background`) num `css/theme.css` em `app/common`, sem precisar do Theme Designer.
- Logo do grupo no `ToolHeader`, ícones `sap-icon://` consistentes (jogo = `soccer`, churrasco = `meal`, pagamento = `money-bills`, votação = `favorite`).
- **Mobile-first:** densidade *cozy* no celular; o `SideNavigation` vira menu recolhido (hambúrguer) em telas pequenas.

**Catálogo de componentes por uso**
| Situação | Componente | Por quê |
|---|---|---|
| Resumo/KPI (rating, pendências, saldo, confirmados) | `sap.f.Card` com `NumericHeader` ou `GenericTile` + `NumericContent` | Número grande, cor por status, clicável para navegar |
| Próximo evento | `sap.f.Card` "cartão do jogo" (data em destaque, local, contagem regressiva, botões grandes) | Ação principal da semana a um toque |
| Quem vai | `f.AvatarGroup` (iniciais/fotos) + "+N" | Visual tipo app de rede social |
| Vagas | `ProgressIndicator` (ex.: 12/16) ou `RadialMicroChart` | Lotação entendida de relance |
| Rating | `RatingIndicator` (só leitura no header, editável na votação) | Estrelas são universais |
| Status (confirmado, pago, pendente, espera) | `ObjectStatus` com `state` e ícone, ou `GenericTag` | Cores semânticas consistentes |
| Listas vazias / sem permissão / erro | `IllustratedMessage` ("Nenhum jogo marcado", "Tudo pago!") | Tela vazia vira mensagem amigável |
| Confirmar presença | `SegmentedButton` **Vou / Não vou** grande, ou dois `Button` `Accept`/`Reject` | Mais rápido que selecionar linha + botão na toolbar |
| PIX | `Image` (QR) + `Input` só leitura com botão **Copiar** + `MessageToast` "Código copiado" | Fluxo igual ao dos apps de banco |
| Comprovante | `upload.UploadSet` com prévia de imagem | Arrastar/fotografar pelo celular |
| Feedback de ações | `MessageToast` (sucesso), `MessageBox` (confirmações destrutivas), `MessagePopover` (erros do backend) | Padrão Fiori |
| Carregamento | `busyIndicatorDelay` + `sap.m.Skeleton`/placeholder nos cards | Sensação de rapidez no plano com cold start |

**Onde os smart controls continuam:** todas as telas de lista com filtro (Agenda completa, Financeiro, Notificações, todas as listas do admin) e todos os formulários de cadastro/edição (perfil, jogadores, eventos, configurações, PIX).

### 6.1 Rotas e views
| Rota | View | Acesso |
|---|---|---|
| `login` | `Login.view.xml` | público |
| `esqueci-senha` | `ForgotPassword.view.xml` | público |
| `redefinir/{token}` | `ResetPassword.view.xml` | público |
| `convite/{token}` | `AcceptInvite.view.xml` | público |
| `` (home) | `Home.view.xml` | logado |
| `agenda` / `agenda/{eventId}` | `Agenda.view.xml` / `EventDetail.view.xml` | logado |
| `votacao` | `Voting.view.xml` | logado |
| `jogo/{eventId}/dia` | `GameDay.view.xml` (check-in, sorteio, times; ações conforme permissão) | logado |
| `pos-jogo/{eventId}` | `PostGame.view.xml` (abas Votação · Meus gols) | logado |
| `rankings` | `Rankings.view.xml` | logado |
| `financeiro` / `financeiro/{chargeId}` | `Charges.view.xml` / `ChargeDetail.view.xml` | logado |
| `notificacoes` | `Notifications.view.xml` | logado |
| `perfil` | `Profile.view.xml` | logado |

`App.view.xml` contém o `tnt.ToolPage`. O header tem nome do grupo, sino de notificações com badge (contagem via `$count` em `Notifications?$filter=lida eq false`) e avatar com menu (Meu perfil, Alterar senha, Ir para Administração se admin, Sair). O `SideNavigation` tem: Início · Agenda e presença · **Dia do jogo** (aparece no dia) · Pós-jogo: votação e gols (badge se pendente) · **Rankings** · Financeiro (badge com pendências) · Notificações. Nas rotas públicas o ToolPage fica escondido.

### 6.2 Login / Esqueci a senha / Redefinir / Convite
As credenciais não são entidades persistidas, então essas views usam uma **entidade virtual** do `AuthService` (`AuthService.Credentials`, `@cds.persistence.skip`) anotada com labels e tipos. A view cria um contexto local com `oModel.createEntry('/Credentials')` (nunca submetido) e liga o `SmartForm` a ele. Assim os campos, labels e validações de tipo vêm do metadata, e o envio é feito pela action correspondente.

- **Visual das telas públicas:** card centralizado (`f.Card`) sobre fundo com imagem/gradiente de gramado, logo e nome do grupo no topo; no celular o card ocupa a tela inteira.
- **Login:** `SmartForm` com `SmartField` E-mail + `Input type=Password` com botão de mostrar/ocultar senha. Botões **Entrar** (`callFunction('/login')`) e **Esqueci a senha** (`navTo('esqueci-senha')`). Se `mustChangePassword`, abre o diálogo de troca de senha.
- **Esqueci a senha:** `SmartForm` com E-mail, CPF (`SmartField` com máscara via `@Common.EditFormat`/formatter) e Data de nascimento (`SmartField` do tipo `Date` renderiza `DatePicker`). Botão **Enviar** → `esqueciSenha`. Sempre mostra a mesma mensagem de sucesso.
- **Redefinir senha** e **Aceitar convite:** nova senha + confirmação; o convite também mostra o checkbox de aceite LGPD (`SmartField` Boolean).

### 6.3 Início (`Home.view.xml`)
Página `f.DynamicPage` com `f.GridContainer` de cards (layout responsivo: 1 coluna no celular, 3 no desktop), ligada a `/Me('<id>')`.
- **Header (cartão de perfil):** `f.Avatar` grande (foto ou iniciais), **nome completo**, apelido · posição, **CPF** mascarado em texto secundário e **RatingIndicator** (só leitura, meia estrela) com o valor "4,3" ao lado e "em N jogos". Se tiver menos de 3 jogos avaliados: `GenericTag` "Em avaliação".
- **Card "Próximo jogo"** (`f.Card`) — se o próximo evento for só churrasco, o mesmo card aparece com o tema do churrasco: data por extenso ("Terça, 18/11 · 20h"), local com link para mapa, contagem regressiva, `ProgressIndicator` de vagas, `AvatarGroup` dos confirmados e `SegmentedButton` **Vou / Não vou**. Se houver churrasco no dia, uma faixa no rodapé do card com o mesmo botão para o churrasco.
- **Cards de KPI** (`GenericTile` + `NumericContent`): **Pendências** (R$, vermelho se > 0, navega para Financeiro), **Presença** (% no ano), **Votação** (badge "Vote agora!" quando aberta).
- **Card "Minha evolução":** `SmartChart` de linha sobre `MyMatchRatings`.
- **Card "Pendências financeiras":** `SmartTable` compacta (até 3 linhas) de `MyCharges` pendentes, com link "Ver todas".
- Estado vazio: `IllustratedMessage` "Nenhum jogo marcado ainda".

### 6.4 Agenda e presença
- **`Agenda.view.xml`:** `SmartFilterBar` (tipo, período) + `SmartTable` de `MyEvents`. O `IconTabBar` com abas **Próximos** / **Histórico** aplica o filtro em `beforeRebindTable`. Colunas: data, tipo, local, minha resposta (criticality), vagas restantes. Botões na toolbar: **Confirmar**, **Recusar**, habilitados conforme a linha selecionada.
- **`EventDetail.view.xml`** (`ObjectPageLayout`):
  - Seção **Detalhes:** `SmartForm` só leitura (data, hora, local, prazo, vagas).
  - Header visual: data em destaque, `ObjectStatus` da minha resposta, `ProgressIndicator` de vagas e `SegmentedButton` **Vou / Não vou**.
  - Seção **Quem vai:** `AvatarGroup` dos confirmados (goleiros e linha separados) + `SmartTable` com a lista completa e a **Lista de espera** (posição na fila).
  - Seção **Churrasco do dia** (visível se houver churrasco vinculado): valor, minha resposta e botões **Vou ao churrasco** / **Não vou**, independentes da resposta do jogo.
  - Seção **Meus convidados:** lista com `Avatar` (iniciais), nome, status (`ObjectStatus`: confirmado/espera) e botão **+ Levar convidado**, que abre um `Dialog` com `SmartForm` (nome, telefone, posição) e um `SegmentedButton` **Jogo / Churrasco / Ambos**. O texto avisa as regras: "convidado entra na lista de espera e é confirmado após o prazo se houver vaga; a cobrança fica no seu nome".
  - Seção **Pagamento do churrasco** (visível depois de confirmar): card PIX igual ao da seção 6.6 (QR Code, copia e cola com botão **Copiar**, valor em destaque) + link para `financeiro/{chargeId}`.
  - Header: **Adicionar ao calendário** (`/ics/{eventId}.ics`) e **Compartilhar no WhatsApp**.
- **Fluxo jogo → churrasco:** ao confirmar o jogo, se houver churrasco no dia, o controller abre um `Dialog` "Bora pro churrasco? 🍖" com ilustração, valor por pessoa em destaque e quem já confirmou (`AvatarGroup`). **Sim** → `vouAoChurrasco` → a resposta traz a cobrança criada e o app navega direto para `financeiro/{chargeId}` para pagar. Isso cumpre "abrir a funcionalidade de pagamento do churrasco ao confirmar o futebol". **Não** é obrigatório: "Agora não" fecha o diálogo, e quem não joga pode confirmar só o churrasco direto no card ou na agenda.
- **Avulso:** ao confirmar o jogo, o app mostra o valor da diária e oferece ir direto ao pagamento, como no churrasco.

### 6.5 Votação (`Voting.view.xml`)
Pensada para ser rápida no celular, logo depois do jogo.
- **Header:** card da partida (data, placar, prazo com contagem regressiva) e `ProgressIndicator` "3 de 12 avaliados".
- **Lista de cartões** (`sap.m.List` com `CustomListItem` ou `f.GridList`, ligada a `BallotItems`): cada cartão tem `Avatar`, nome, posição, **RatingIndicator editável** (estrelas grandes, toque para avaliar) e um botão-ícone de troféu para marcar o **Craque da partida** (só um ativo por vez).
- **Enviar votos** fica habilitado quando todos estiverem avaliados. Usa o grupo deferido + `callFunction('/enviarVotos')`, depois mostra `IllustratedMessage` "Votos enviados! Resultado em 48h".
- Votação fechada ou já enviada: `IllustratedMessage` correspondente.
- Exceção consciente à regra "dados → smart control": a cédula é uma interação, não uma tabela de dados, e uma SmartTable com estrelas fica pouco usável no celular.

### 6.5.1 Dia do jogo e pós-jogo (visão do jogador)
- **Dia do jogo (`GameDay.view.xml`):** botão grande **Cheguei** (na janela de check-in), lista de quem já chegou em ordem de chegada (`Avatar` + número) e, depois de publicados, o card **Times de hoje**: uma coluna por time com a cor do colete, jogadores, goleiro e força média. O próprio time fica destacado. O organizador do dia vê na mesma tela os botões de check-in, **Sortear**, **Trocar** e **Publicar** (seção 7.0.2).
- **Pós-jogo (`PostGame.view.xml`):** aba **Votação** (seção 6.5) e aba **Meus gols**, com `StepInput` de gols, para cada gol a escolha do assistente (lista de `Avatar`s do próprio time) e a lista de lançamentos do jogo com botão **Contestar**. Uma notificação avisa quando alguém credita uma assistência a você.
- **Rankings:** pódio + tabela (seção 7.0.3).

### 6.6 Financeiro
- **`Charges.view.xml`:** no topo, dois `GenericTile`s (**Total pendente** em vermelho, **Pago no ano** em verde). Abaixo, `IconTabBar` com contadores (**Pendentes** · **Em análise** · **Pagos**) + `SmartFilterBar` (tipo, competência, período) + `SmartTable` de `MyCharges` com status em `ObjectStatus` colorido. Aba vazia: `IllustratedMessage` "Tudo pago! ⚽".
- **`ChargeDetail.view.xml`** (`ObjectPageLayout`):
  - Seção **Dados:** `SmartForm` (descrição, tipo, competência/evento, vencimento, valor, status com criticality, motivo da rejeição).
  - Seção **Pagar com PIX** (card em destaque): valor grande, `Image` com o QR Code, campo com o **PIX copia e cola** e botão **Copiar** (`navigator.clipboard` + `MessageToast` "Código copiado, cole no app do seu banco"), favorecido e chave. Passo a passo em 3 etapas com ícones: *Copie → Pague no banco → Envie o comprovante*.
  - Seção **Comprovante:** `sap.m.upload.UploadSet` (exceção D2) enviando para a media stream `Charges(id)/comprovante` (PUT); depois `callFunction('/informarPagamento')`.

### 6.7 Notificações e perfil
- **Notificações:** `SmartTable` de `Notifications` com botões **Marcar como lida** e **Marcar todas**; clique na linha navega para o `link` interno.
- **Perfil:** `SmartForm` editável (apelido, telefone, posição) + foto via `UploadSet` + botão **Alterar senha** (`Dialog`).

---

## 7. App do Administrador (`app/admin` — UI5 freestyle)

Mesmos padrões da seção 6.0, com o modelo em `/odata/v2/admin`. Mesmo login (rotas públicas iguais). O guard exige `isAdmin`; se não for admin, redireciona para `/player`. No app do jogador, admins veem o atalho **Administração** no menu do avatar.

`SideNavigation`: Painel · Jogadores · Eventos · Pagamentos · Caixa · Configurações · Auditoria.

| Menu | Views | Conteúdo com smart controls |
|---|---|---|
| **Painel** | `Dashboard.view.xml` | `f.GridContainer` com **cards e tiles** sobre a view `DashboardKpis`: próximo jogo (`ProgressIndicator` de vagas + `AvatarGroup`), **pagamentos aguardando aprovação** (tile com número, clicável), inadimplência (R$ e nº de jogadores), **saldo do caixa**, top 5 do ranking (lista com `Avatar` + `RatingIndicator`). Gráficos em **`SmartChart`**: presença por jogo, inadimplência por mês, entradas x despesas |
| **Jogadores** | `Players.view.xml`, `PlayerDetail.view.xml` | Lista: `SmartFilterBar` (status, tipo, posição, admin) + `SmartTable` (nome, apelido, e-mail, tipo, status, rating, % presença, pendência). Toolbar: **Novo jogador**, **Convidar**, **Reenviar convite**. Detalhe: `SmartForm` editável (dados pessoais, tipo, posição) + `SmartTable`s de presença, cobranças e notas por partida. Header: **Redefinir senha**, **Tornar admin / Remover admin**, **Inativar / Reativar** |
| **Novo jogador** | `Dialog` com `SmartForm` | `oModel.createEntry('/Players', { groupId: 'changes' })` → Salvar → pergunta se já quer enviar o convite |
| **Eventos** | `Events.view.xml`, `EventDetail.view.xml` | Lista: `SmartFilterBar` (tipo, status, período) + `SmartTable`. **Novo evento** abre o assistente da seção 7.0.1 (tipo → dados → cobrança → regras → publicar). Detalhe: `SmartForm` do evento; `SmartTable` editável de **presenças** (jogador ou convidado + quem convidou, status, presente, time, gols, assistências) com botão **Adicionar participante avulso**; `SmartTable` de **cobranças do evento**; `SmartChart` de barras com a média de notas por jogador (agregada, anônima). Seção **Faixas de preço** (`SmartTable` editável) e, no rateio, custo total + valor calculado. Header: **Publicar**, **Criar evento vinculado**, **Duplicar**, **Prestação de contas**, **Fechar lista**, **Sortear times**, **Registrar resultado**, **Abrir/Encerrar votação**, **Cancelar** |
| **Pagamentos** | `Payments.view.xml`, `PaymentDetail.view.xml` | `IconTabBar` (**Aguardando aprovação** · **Pendentes** · **Vencidos** · **Aprovados**) + `SmartFilterBar` (jogador, tipo, competência) + `SmartTable` com **seleção múltipla**. Toolbar: **Aprovar**, **Rejeitar** (`Dialog` com motivo), **Cancelar**, **Nova cobrança avulsa**, **Gerar mensalidades do mês**. Detalhe: `SmartForm` + prévia grande do comprovante (`Image` com zoom em `LightBox`, ou link do PDF) e botões grandes **Aprovar** / **Rejeitar** no rodapé |
| **Caixa** | `Cashflow.view.xml` | `SmartTable` editável de `Expenses` + `SmartChart` entradas x saídas por mês + `SmartForm` com o saldo (view `Balance`). Filtro por churrasco para a prestação de contas |
| **Configurações** | `Settings.view.xml`, `PixKeys.view.xml`, `EmailTemplates.view.xml` | **Central de Configurações** (seção 7.0): todos os parâmetros por grupo, chaves PIX, regras de notificação, modelos de e-mail e histórico de alterações |
| **Auditoria** | `Audit.view.xml` | `SmartFilterBar` (ação, usuário, período) + `SmartTable` só leitura |

**Convite de jogador:** admin cadastra nome, e-mail, CPF, nascimento, tipo e posição → **Convidar** → e-mail com link `.../player/#/convite/{token}` (validade 7 dias) → jogador define a senha → status `ATIVO`.

**Redefinir senha pelo admin:** gera uma senha temporária exibida uma única vez num `Dialog` (ou enviada por e-mail) e marca `mustChangePassword = true`. O admin **nunca** vê a senha atual.

**Tornar admin:** adiciona o papel `Admin`; vale no próximo login/refresh do token. Não é permitido remover o último admin.

**Sortear times:** ver seção 7.0.2. A tela `GameDay` é a mesma do app do jogador, com todas as ações liberadas para o admin.

### 7.0 Central de Configurações (nova funcionalidade)

**Princípio:** toda regra de negócio que possa variar é um **parâmetro**, nunca um valor fixo no código. O admin muda pelo app, sem deploy. Os padrões abaixo refletem as decisões da seção 1.5. Por exemplo, o **bloqueio por inadimplência existe, mas vem desligado**.

**Tela (`Settings.view.xml`):** `ObjectPageLayout` com barra de âncoras, uma seção por grupo. Cada seção é um `SmartForm` ligado a um `@UI.FieldGroup` do singleton `Settings`. Os parâmetros de liga/desliga são `SmartField` Boolean (switch) e os campos dependentes ficam visíveis/editáveis só quando o switch está ligado (`@UI.Hidden` / `@Common.FieldControl` calculado no backend). Botões **Editar / Salvar / Cancelar** e **Restaurar padrões do grupo**. Cada alteração vai para o `AuditLog` com valor antigo e novo, e uma aba **Histórico** mostra quem mudou o quê.

| Grupo | Parâmetro | Tipo | Padrão |
|---|---|---|---|
| **Geral** | Nome do grupo, logo, cor de destaque | texto / imagem / cor | "Futebol de Terça", —, `#1B8A3A` |
| | Dia da semana e hora padrão do jogo, duração, local padrão | lista / hora / min / texto | Terça, 20:00, 60 min, — |
| **Tipos de evento** | Cadastro de tipos (nome, categoria, ícone, cor, cobrança padrão, faixas de preço, PIX, convidados, vagas, prazos) | `SmartTable` de `EventTypes` | Jogo de terça, Churrasco, Confraternização de fim de ano |
| | Cobrança agrupada (uma cobrança com o total do jogador + convidados) | switch | Ligado |
| **Agenda automática** | Criar jogos automaticamente (recorrência semanal) | switch | Ligado |
| | Quantas semanas à frente criar | número | 2 |
| | Publicar automaticamente (já pedir confirmação) | switch | Ligado |
| | Criar churrasco junto com o jogo | switch | Desligado |
| **Presença** | Vagas de linha / goleiro | número | 14 / 2 |
| | Prazo de confirmação (horas antes do jogo) | número | 4 |
| | Permitir confirmar após o prazo (se houver vaga) | switch | Ligado |
| | Lista de espera com promoção automática | switch | Ligado |
| | Permitir desistir após o prazo | switch | Ligado |
| | Permitir ir só ao churrasco | switch | Ligado |
| | Sugerir churrasco ao confirmar o jogo | switch | Ligado |
| **Convidados** | Permitir convidados no jogo / no churrasco | switch / switch | Ligado / Ligado |
| | Máximo de convidados por jogador por evento | número | 2 |
| | Convidado só garante vaga após o prazo | switch | Ligado |
| | Valor da diária do convidado / churrasco do convidado | moeda | = diária avulso / = churrasco |
| | Cobrança no nome de quem convidou | switch | Ligado |
| **Financeiro** | Valor da mensalidade / diária do avulso / churrasco padrão | moeda | a definir |
| | Dia de vencimento da mensalidade | número (1–28) | 10 |
| | Gerar mensalidades automaticamente (dia do mês) | switch + número | Ligado, dia 1 |
| | Prazo para pagar diária/churrasco (dias após o evento) | número | 3 |
| | Chave PIX da mensalidade / diária / churrasco padrão | lista (PixKeys) | — |
| | Exigir comprovante para informar pagamento | switch | Ligado |
| | Guardar comprovantes por (meses) | número | 6 |
| **Inadimplência** | Enviar lembretes de vencimento | switch | **Ligado** |
| | Lembrar X dias antes / a cada Y dias depois do vencimento | número / número | 2 / 3 |
| | **Bloquear confirmação de presença de inadimplentes** | switch | **Desligado** |
| | ↳ Tolerância (dias após o vencimento) / valor mínimo em aberto | número / moeda | 15 / R$ 0,01 |
| | ↳ Bloquear também churrasco / votação | switch / switch | Desligado / Desligado |
| | Multa por atraso | switch + % ou R$ | Desligado |
| | Mostrar lista de pendências para todo o grupo (transparência) | switch | Desligado |
| **Faltas** | Registrar falta quando confirmou e não foi (check-in) | switch | Desligado |
| | ↳ Prazo para desistir sem contar falta (horas antes) | número | 4 |
| | ↳ Multa por falta | switch + moeda | Desligado |
| | ↳ Suspender após N faltas / por quantos jogos | switch + número + número | Desligado, 3, 1 |
| **Votação** | Habilitar votação | switch | Ligado |
| | Abrir automaticamente X horas após o jogo / janela (horas) | número / número | 2 / 48 |
| | Votos anônimos | switch | Ligado |
| | Craque da partida | switch | Ligado |
| | Jogos mínimos para exibir o rating | número | 3 |
| | Cálculo do rating: média das médias por jogo / média simples / últimos N jogos | lista + número | Média das médias, todos |
| | Rating visível para: todos / só o próprio jogador e admins | lista | Todos |
| **Dia do jogo / sorteio** | Quem pode sortear | lista | Admin + organizador do dia |
| | Check-in pelo próprio jogador / janela (min antes e depois do início) | switch / números | Ligado / 30 / 30 |
| | Modo de sorteio | lista (Equilibrado, Aleatório, Ordem de chegada, Capitães) | Equilibrado |
| | **Jogadores de linha por time** / goleiro por time | número / número (0 ou 1) | **6** / 1 |
| | Número de times automático ou fixo | switch + número | Automático |
| | Sobra de jogadores | lista (Time de espera, Distribuir) | Time de espera |
| | Sem goleiro suficiente | lista (Rodízio, Sem goleiro) | Rodízio |
| | Cores dos coletes | lista de texto | Laranja, Verde, Sem colete |
| | Rating padrão do novato/convidado / força pelos últimos N jogos | número / número | 3,0 / 10 |
| | Peso das estatísticas (gols+assist.) na força | 0–1 | 0 |
| | Equilibrar posições de linha / evitar repetir duplas (últimos M jogos) | switch / switch + número | Ligado / Ligado, 3 |
| | Soluções geradas / tolerância para sortear entre as melhores | número / % | 300 / 3% |
| | Atrasado entra no | lista (Time de espera, Time mais fraco) | Time de espera |
| | Restrições juntos/separados | `SmartTable` de `DrawConstraints` | — |
| **Artilharia e assistências** | Habilitar estatísticas | switch | Ligado |
| | Quem lança os gols | lista (Próprio jogador, Qualquer participante, Organizador/admin) | Próprio jogador |
| | Validação | lista (Automática com contestação, Confirmação por colega, Aprovação do admin) | Automática |
| | Prazo de contestação (horas) / máximo de gols por jogo | número / número | 24 / 15 |
| | Registrar gol contra / registrar partidas e placares | switch / switch | Desligado / Desligado |
| | Início da temporada / critério de desempate | data / lista | 1º de janeiro / menos jogos, mais assistências |
| **Notificações** | Canal por tipo de aviso (no app, e-mail) — matriz | `SmartTable` de `NotificationRules` | Tudo no app; e-mail para convite, senha, novo jogo, cobrança e aprovação |
| | Lembrete de confirmação X horas antes do prazo | número | 24 |
| | Horário silencioso (não enviar entre) | hora / hora | 23:00 / 07:00 |
| | Modelos de e-mail (assunto e corpo com variáveis `{{nome}}`, `{{data}}`, `{{valor}}`, `{{link}}`) | `SmartTable` de `EmailTemplates` | Modelos padrão |
| **Segurança** | Tentativas de login antes de bloquear / minutos bloqueado | número / número | 5 / 15 |
| | Validade do convite (dias) / do link de senha (min) / da sessão (dias) | número | 7 / 30 / 7 |
| | Tamanho mínimo da senha | número | 8 |
| **Privacidade (LGPD)** | Texto dos termos de uso / versão | texto longo / texto | modelo padrão / 1 |
| | Exigir novo aceite quando a versão mudar | switch | Ligado |

**Regras técnicas da configuração**
- **Leitura centralizada:** `srv/lib/settings.js` com cache em memória, invalidado no `after('UPDATE', 'Settings')`. Nenhum handler lê constantes; todos chamam `settings.get('grupo.parametro')`.
- **Validação no backend** (`before('UPDATE', 'Settings')`): faixas válidas (ex.: vencimento entre 1 e 28), dependências (bloqueio ligado exige tolerância definida) e chaves PIX ativas.
- **Sem efeito retroativo:** ao criar um evento ou uma cobrança, os valores vigentes (vagas, prazo, valores, PIX) são **copiados** para o registro. Mudar a configuração afeta só o que for criado depois. O admin pode ajustar manualmente um evento já criado.
- **Jogos e jobs seguem a configuração:** o GitHub Actions chama um único `POST /jobs/tick` **a cada hora**, e o backend decide o que rodar naquele momento com base nos parâmetros (dia de gerar mensalidade, horário de lembrete, horário silencioso etc.). Assim os horários também ficam configuráveis pelo app, sem mexer no workflow.
- **Visibilidade para o jogador:** o app do jogador lê uma projeção somente leitura `PublicSettings` (valores, regras de convidados, prazo, se o bloqueio está ligado) para mostrar as regras na tela, como "confirmação até 16h" ou "você pode levar até 2 convidados".

### 7.0.1 Cadastro de eventos (jogo, churrasco, fim de ano e outros)

**Tipos de evento configuráveis** (Central de Configurações → *Tipos de evento*, `SmartTable` editável de `EventTypes`). O admin cria quantos tipos quiser. Padrões entregues:

| Tipo | Categoria | Cobra? | Convidados | Vagas | Votação |
|---|---|---|---|---|---|
| Jogo de terça | `JOGO` | Diária só para avulso/convidado | Sim | Sim (linha/goleiro) | Sim |
| Churrasco | `SOCIAL` | Sim, valor por pessoa | Sim | Não | Não |
| Confraternização de fim de ano | `SOCIAL` | Sim, valor por pessoa ou rateio | Sim | Opcional | Não |
| Outro (torneio, aniversário do grupo...) | `JOGO` ou `SOCIAL` | Configurável | Configurável | Configurável | Só `JOGO` |

Cada tipo traz os **padrões** que pré-preenchem o evento: ícone, cor, valores, PIX, convidados, vagas, prazo de confirmação. No evento, tudo pode ser alterado.

**Formas de cobrança por evento** (`modoCobranca`):
- `POR_PESSOA` (padrão): valor fixo por participante, com **faixas de preço** (ver abaixo).
- `RATEIO`: o admin informa o **custo total** e, ao fechar a lista, o sistema divide pelo número de pagantes (com arredondamento para cima em centavos) e gera as cobranças. Mostra ao jogador uma **estimativa** ("~R$ 45 com 20 confirmados") enquanto a lista está aberta.
- `GRATUITO`: só confirmação de presença, sem cobrança (ex.: caixa do grupo paga tudo).

**Faixas de preço** (`EventPrices`, composição do evento). Permite valores diferentes por perfil, por exemplo:

| Faixa | Valor |
|---|---|
| Jogador do grupo | R$ 50,00 |
| Convidado | R$ 60,00 |
| Criança até 12 anos | R$ 25,00 |
| Criança até 5 anos | Grátis |

O jogador confirma a si mesmo na faixa "Jogador" e, para cada convidado, escolhe a faixa (ex.: esposa = Convidado, filho = Criança até 12). Cada participante gera uma linha de cobrança no nome do jogador, ou uma cobrança única com o total, conforme o parâmetro `cobrancaAgrupada`.

**Vínculo com o jogo (opcional):** um evento social pode ficar **vinculado** a um jogo (ex.: churrasco depois do jogo de terça), e então aparece no card do jogo e no diálogo "Bora pro churrasco?". Pode também ser **independente**, em outra data, como a confraternização de fim de ano num sábado de dezembro.

**Tela do admin — Novo evento** (`sap.m.Wizard`, cada passo com `SmartForm`):
1. **Tipo:** escolha do tipo (cards com ícone). Os padrões do tipo preenchem os próximos passos.
2. **Dados:** título, data, hora início/fim, local, descrição, imagem de capa opcional (`UploadSet`), vínculo opcional com um jogo.
3. **Cobrança:** modo (`SegmentedButton` Por pessoa / Rateio / Gratuito), `SmartTable` editável de **faixas de preço** ou custo total, chave PIX, prazo de pagamento.
4. **Regras:** vagas (opcional), prazo de confirmação, convidados (sim/não, máximo por jogador), quem é convidado (todos os ativos, só mensalistas ou seleção manual).
5. **Revisar e publicar:** resumo em card + **Salvar rascunho** ou **Publicar** (notifica os convidados do evento).

Ações extras no detalhe do evento: **Duplicar** (ex.: copiar o fim de ano do ano passado), **Fechar lista** (no rateio, calcula e gera as cobranças), **Prestação de contas** (custo real x arrecadado, lançando despesas no Caixa), **Cancelar**.

**Visão do jogador:** a Agenda lista todos os eventos com ícone/cor do tipo e capa. O detalhe mostra descrição, faixas de preço (ou estimativa do rateio), quem vai (`AvatarGroup`) e o botão **Vou / Não vou**. Ao confirmar um evento pago, o app oferece levar convidados (com escolha de faixa) e depois vai direto para o pagamento PIX com o total.

### 7.0.2 Dia do jogo: check-in e sorteio de times

**Fluxo no dia**
1. **Check-in (quem chegou):** a lista de presença do jogo vira uma tela de chegada. O **organizador do dia** marca quem chegou (`SegmentedButton` Chegou / Faltou em cada cartão). O jogador também pode tocar **Cheguei** no próprio app numa janela configurável (padrão: 30 min antes até 30 min depois do início). A ordem de chegada é gravada (`ordemChegada`) e serve de critério de desempate e de lista de espera. Quem chegou sem ter confirmado pode ser incluído ali mesmo, assim como convidados.
2. **Sorteio:** com os presentes definidos, **Sortear times**. Só entra no sorteio quem fez check-in.
3. **Revisão:** o resultado aparece em colunas, uma por time, com cor do colete, força total/média e um **indicador de equilíbrio** ("diferença de 3%"). O organizador pode **trocar dois jogadores** manualmente (arrastar ou selecionar par → Trocar). O indicador é recalculado na hora.
4. **Publicar:** os times ficam visíveis para todos no app (card "Times de hoje" na Início e no detalhe do jogo), com notificação e botão **Compartilhar no WhatsApp** (texto pronto com times e cores).
5. **Chegou atrasado:** **Adicionar ao jogo** coloca o jogador no time de espera ou no time mais fraco, conforme configuração, sem refazer o sorteio.

**Quem pode sortear** (configurável): só admin, admin + **organizador do dia** (padrão; um jogador designado no evento), ou qualquer confirmado presente.

**Transparência anti-"panela":** cada sorteio grava semente (seed), critérios, quem executou e horário (`DrawLogs`). Se alguém sortear de novo depois do primeiro resultado, o app mostra para todos "Sorteio refeito 2 vezes por Fulano". Os times publicados ficam travados; mudanças depois disso ficam no histórico.

**Quantidade de jogadores e formato (configurável)**
- **Jogadores de linha por time** (padrão 6) e **goleiro por time** (padrão 1; 0 para rodízio de goleiro).
- **Número de times:** automático = `presentes de linha ÷ jogadores por time` (arredondado para baixo) ou fixo.
- **O que fazer com a sobra:** *Time de espera* (padrão: os que sobram formam o próximo time e são completados por quem chegar; formato "quem perde sai") ou *Distribuir* (alguns times ficam com um jogador a mais).
- **Faltou goleiro:** jogador de linha vai para o gol em rodízio (marcado no time) ou time sem goleiro fixo.
- **Cores dos coletes:** lista configurável (ex.: Laranja, Verde, Sem colete), atribuídas em ordem aos times.

**Modos de sorteio** (configurável; padrão *Equilibrado*):
| Modo | Como funciona | Quando usar |
|---|---|---|
| **Equilibrado** (recomendado) | Algoritmo abaixo, usando a força de cada jogador | Padrão do grupo |
| Aleatório puro | Embaralha (respeitando goleiros) | Jogo festivo |
| Ordem de chegada | Primeiros N formam o time 1, próximos N o time 2... | Pelada "clássica" |
| Capitães | O app sugere 2 capitães (maiores ratings ou escolhidos) e eles escolhem alternadamente no app (ordem 1-2-2-1) | Quando o grupo prefere escolher |

**Algoritmo do modo Equilibrado (como escolher o melhor time)**

*1. Força de cada jogador*
```
força = rating (0–5)                                   // média das votações (seção 5.4)
      + pesoEstatisticas × (gols + assistências por jogo, normalizado 0–1)   // opcional, padrão 0
jogador sem rating (novato / convidado) → ratingPadraoNovato (padrão 3,0) ou nota inicial definida pelo admin
```
O rating usado é o da **média dos últimos N jogos** (configurável), para refletir a fase atual.

*2. Montagem inicial (snake draft)*
- Goleiros primeiro: ordenados por força e distribuídos um por time.
- Linha: ordenada por força e distribuída em "cobra" (time 1, 2, 3, 3, 2, 1, 1, 2...). Se o equilíbrio por posição estiver ligado, faz isso dentro de cada grupo (Defesa, Meio, Ataque, se o jogador informou a posição preferida).

*3. Otimização com variedade* (ótimo para até ~40 jogadores, roda em milissegundos no backend)
- Gera **K soluções** (padrão 300): cada uma parte do snake draft com embaralhamento dentro de "faixas" de jogadores de força parecida e aplica **trocas 1-a-1** entre times enquanto o custo cair (busca local / hill climbing).
- **Custo** de uma solução:
  ```
  custo = w1 × desvio-padrão da força total dos times          // equilíbrio (principal)
        + w2 × desequilíbrio de posições (defesa/meio/ataque)
        + w3 × nº de duplas que jogaram juntas nos últimos M jogos  // evita repetir os mesmos times
        + w4 × violações de restrições (juntos/separados)
  ```
- Entre as soluções com custo até **X% do melhor** (padrão 3%), escolhe **uma aleatoriamente**. Os times saem equilibrados, mas não repetem toda semana nem dão para "adivinhar".
- **Restrições opcionais** (`DrawConstraints`, mantidas pelo admin): pares que devem jogar **juntos** (ex.: pai e filho convidado) ou **separados** (ex.: os dois melhores goleiros-linha).

*4. Resultado:* times com força total e média, indicador de equilíbrio `(maior − menor) ÷ média`, seed e parâmetros usados, tudo gravado em `DrawLogs`.

### 7.0.3 Artilharia e assistências (preenchidas pelos jogadores)

**Lançamento ("súmula colaborativa")**
- Depois do jogo, na mesma janela da votação (configurável), cada jogador abre **Pós-jogo → Meus gols** e lança seus gols: `StepInput` com a quantidade ou um gol por vez. Para cada gol, pode indicar **quem deu a assistência** (lista de jogadores do mesmo time no sorteio, com `Avatar`).
- A assistência **é creditada automaticamente** a quem foi indicado, que recebe uma notificação ("Fulano registrou uma assistência sua. Confirmar?").
- **Gol contra** (opcional): registrado sem artilheiro, só no placar.
- **Quem pode lançar** (configurável): só o próprio jogador (padrão), qualquer participante do jogo, ou só o organizador/admin. Convidados não têm login, então quem os trouxe ou o organizador lança por eles.
- **Validação** (configurável):
  - *Automática* (padrão): vale na hora; qualquer participante pode **contestar** em até 24h. Lançamento contestado vai para o organizador/admin decidir.
  - *Confirmação por outro jogador do mesmo time:* o gol fica pendente até um colega confirmar.
  - *Aprovação do admin.*
- **Limite de sanidade:** máximo de gols por jogador por jogo (padrão 15). Acima disso exige aprovação.
- Admin/organizador pode corrigir qualquer lançamento (fica no `AuditLog`).
- **Partidas e placares (opcional):** se ligado, o organizador registra as partidas da noite (Time A x Time B, placar) e cada gol pode ser ligado a uma partida, o que permite estatística de vitórias por jogador.

**Rankings (`Rankings.view.xml`, novo item do menu "Rankings")**
- **Pódio visual** (cards com `Avatar`, medalhas ouro/prata/bronze) + `SmartTable` completa com `SmartFilterBar` (período: mês, ano, **temporada** configurável, todos; tipo de evento).
- Abas: **Artilharia** (gols, média por jogo) · **Assistências** · **Participações em gol** (G+A) · **Craque da partida** (votos) · **Presença**.
- Critérios de desempate configuráveis (padrão: menos jogos, depois mais assistências).
- **Meus números** na Início: gols, assistências, jogos e posição no ranking da temporada (`GenericTile`s).
- **Fim de temporada** (opcional): o admin encerra a temporada e o app destaca os campeões (Chuteira de Ouro, Garçom, Craque da temporada), com o histórico guardado.
- `SmartChart` de evolução de gols por mês no perfil do jogador.

### 7.1 Anotações que alimentam os smart controls (exemplo)
```cds
annotate AdminService.Charges with @(
  UI.SelectionFields: [ player_ID, tipo_code, status_code, competencia ],
  UI.LineItem: [
    { Value: player.nomeCompleto, Label: 'Jogador' },
    { Value: descricao },
    { Value: vencimento },
    { Value: valor },
    { Value: status_code, Criticality: statusCriticality }
  ],
  UI.FieldGroup#Dados: { Data: [
    { Value: descricao }, { Value: tipo_code }, { Value: competencia },
    { Value: vencimento }, { Value: valor }, { Value: status_code }, { Value: motivoRejeicao }
  ]}
) {
  player @Common: { Text: player.nomeCompleto, TextArrangement: #TextOnly,
                    ValueList: { CollectionPath: 'Players', Parameters: [
                      { $Type: 'Common.ValueListParameterInOut', LocalDataProperty: player_ID, ValueListProperty: 'ID' },
                      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'nomeCompleto' } ] } };
  status @Common: { Text: status.name, TextArrangement: #TextOnly, ValueListWithFixedValues };
};
```

### 7.2 Exemplo de view (lista de pagamentos)
```xml
<mvc:View controllerName="futebol.admin.controller.Payments"
  xmlns:mvc="sap.ui.core.mvc" xmlns="sap.m"
  xmlns:smartFilterBar="sap.ui.comp.smartfilterbar"
  xmlns:smartTable="sap.ui.comp.smarttable">
  <Page title="{i18n>paymentsTitle}">
    <smartFilterBar:SmartFilterBar id="sfbPayments" entitySet="Charges" persistencyKey="sfbPayments"/>
    <IconTabBar id="tabs" select=".onTabSelect">
      <items>
        <IconTabFilter key="INFORMADO" text="{i18n>awaitingApproval}"/>
        <IconTabFilter key="PENDENTE"  text="{i18n>pending}"/>
        <IconTabFilter key="VENCIDO"   text="{i18n>overdue}"/>
        <IconTabFilter key="APROVADO"  text="{i18n>approved}"/>
      </items>
    </IconTabBar>
    <smartTable:SmartTable id="stPayments" entitySet="Charges" smartFilterId="sfbPayments"
      tableType="ResponsiveTable" useVariantManagement="true" useExportToExcel="true"
      persistencyKey="stPayments" beforeRebindTable=".onBeforeRebind" enableAutoBinding="true">
      <smartTable:customToolbar>
        <OverflowToolbar>
          <ToolbarSpacer/>
          <Button text="{i18n>approve}" type="Accept" press=".onApprove"/>
          <Button text="{i18n>reject}"  type="Reject" press=".onReject"/>
        </OverflowToolbar>
      </smartTable:customToolbar>
      <Table mode="MultiSelect" growing="true"/>
    </smartTable:SmartTable>
  </Page>
</mvc:View>
```

---

## 8. Funcionalidades extras propostas

Priorizadas por valor x esforço:

**Fase 1 (MVP+, alto valor, baixo esforço)**
1. **Lista de espera automática** com vagas separadas para goleiro e linha, promoção automática e notificação.
2. ~~Mensalista x avulso~~ e **convidados**: incorporados ao escopo principal (decisões 4 e 7).
3. **Geração automática de mensalidades** + lembretes de vencimento.
4. **Adicionar ao calendário (.ics)** e **compartilhar no WhatsApp**.
5. **Craque da partida** na votação e ranking mensal.
6. **Caixa do grupo** (despesas x arrecadação) com saldo visível para os jogadores (transparência).

**Fase 2**
7. ~~Sorteio de times~~: incorporado ao escopo (seção 7.0.2).
8. ~~Artilharia e assistências~~: incorporadas ao escopo (seção 7.0.3). Extras futuros: sequência de jogos, estatística de goleiro (gols sofridos), vitórias por jogador.
9. **Check-in no dia e controle de faltas**: já previsto como parâmetros na Central de Configurações (desligados por padrão).
10. **Prestação de contas do churrasco**: custo real x arrecadado, rateio de sobra/falta.
11. **PWA + Web Push**.

**Fase 3**
12. **PIX dinâmico com PSP** (baixa automática via webhook).
14. **Aniversariantes do mês** no painel; **regras do grupo** (página fixa).
15. **Exportação** (Excel pela SmartTable, já nativo com `useExportToExcel`) e relatório mensal por e-mail para os admins.

---

## 9. Repositório, CI/CD e deploy no Render

### 9.1 Estrutura do repositório (`github.com/<usuario>/futebol-terca`)
```
futebol-terca/
├─ app/
│  ├─ common/                    # BaseController, formatter, auth guard, css, i18n compartilhado
│  ├─ player/                    # app freestyle do jogador
│  │  └─ webapp/
│  │     ├─ Component.js  manifest.json  index.html
│  │     ├─ controller/          # App, Login, ForgotPassword, ResetPassword, AcceptInvite,
│  │     │                       # Home, Agenda, EventDetail, Voting, Charges, ChargeDetail,
│  │     │                       # Notifications, Profile
│  │     ├─ view/                # *.view.xml (smart controls)
│  │     ├─ fragment/            # dialogs (troca de senha, churrasco, rejeição...)
│  │     ├─ model/ formatter.js models.js
│  │     └─ i18n/
│  └─ admin/                     # app freestyle do administrador (mesma estrutura)
│     └─ webapp/ ...             # Dashboard, Players, PlayerDetail, Events, EventDetail,
│                                # Payments, PaymentDetail, Cashflow, Settings, Audit
├─ db/
│  ├─ schema.cds
│  ├─ views.cds
│  └─ data/                  # CSV das code lists (+ seeds de dev)
├─ srv/
│  ├─ auth-service.cds|.js
│  ├─ player-service.cds|.js
│  ├─ admin-service.cds|.js
│  ├─ jobs-service.cds|.js
│  ├─ annotations/           # anotações UI por app
│  ├─ lib/ auth.js  pix.js  mailer.js  ics.js  cpf.js  draw.js
│  └─ server.js              # bootstrap: helmet, rate-limit, cookie-parser, rotas /pix/qrcode
├─ test/                     # jest + cds.test
├─ .github/workflows/
│  ├─ ci.yml                 # lint + testes em todo PR
│  ├─ jobs.yml               # cron de hora em hora → /jobs/tick
│  ├─ backup.yml             # pg_dump diário criptografado
│  └─ rotate-db.yml          # renovação do Render Postgres Free
├─ render.yaml               # Blueprint (web service + postgres)
├─ .env.example
├─ package.json
└─ README.md
```

### 9.2 Dependências principais
`@sap/cds`, `@cap-js/postgres`, `@cap-js/sqlite` (dev), `@cap-js-community/odata-v2-adapter`, `express`, `bcryptjs`, `jsonwebtoken`, `cookie-parser`, `helmet`, `express-rate-limit`, `qrcode`, cliente do provedor de e-mail. Dev: `@sap/cds-dk`, `@ui5/cli` (build/minificação dos apps), `@sap/eslint-plugin-ui5-jsdocs`, `jest`, `eslint`. UI5 carregado da CDN (`https://ui5.sap.com/<versão>/resources/sap-ui-core.js`) com as bibliotecas `sap.m`, `sap.ui.comp`, `sap.tnt`, `sap.uxap`, `sap.f`, `sap.ui.layout`, `sap.suite.ui.microchart` (opcional) e o tema `sap_horizon`.

### 9.3 Configuração CDS (trecho do `package.json`)
```json
"cds": {
  "requires": {
    "auth": { "kind": "custom", "impl": "srv/lib/auth.js" },
    "db": { "kind": "sqlite", "credentials": { "url": ":memory:" } },
    "[production]": {
      "db": { "kind": "postgres", "schema_evolution": "auto" }
    }
  },
  "protocols": { "odata-v2": { "path": "/odata/v2" } }
}
```
No Render, as credenciais do Postgres entram por variáveis de ambiente (`CDS_REQUIRES_DB_CREDENTIALS_HOST`, `_PORT`, `_USER`, `_PASSWORD`, `_DATABASE`) ou fazendo o parse de `DATABASE_URL` em `server.js`. Use a **Internal Database URL** (mesma região, sem tráfego externo).

### 9.4 `render.yaml` (Blueprint)
```yaml
databases:
  - name: futebol-db          # renovado a cada ~25 dias (seção 9.5)
    databaseName: futebol
    plan: free
services:
  - type: web
    name: futebol-terca
    runtime: node
    plan: free
    buildCommand: npm ci && npx cds build --production
    startCommand: npx cds-deploy && npx cds-serve   # deploy do schema + start
    healthCheckPath: /health
    envVars:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL       # atualizada pelo workflow de renovação; usar a Internal URL
        sync: false
      - key: JWT_SECRET
        generateValue: true
      - key: JOB_SECRET
        generateValue: true
      - key: MAIL_PROVIDER
        value: gmail
      - key: GMAIL_CLIENT_ID
        sync: false
      - key: GMAIL_CLIENT_SECRET
        sync: false
      - key: GMAIL_REFRESH_TOKEN
        sync: false
      - key: MAIL_FROM
        sync: false
      - key: APP_BASE_URL
        sync: false
```

### 9.5 Plano gratuito: limites e como contornar
| Limite do plano gratuito | Impacto | Solução |
|---|---|---|
| Web Service dorme após 15 min sem tráfego, ~1 min para acordar | Primeiro acesso lento | Keep-alive (seção 3.6) + skeletons/busy indicator na UI |
| 750 h/mês de instância gratuita por workspace | Um serviço 24h usa ~744 h | Manter **um único** serviço gratuito no workspace |
| SMTP bloqueado | Sem `nodemailer` via SMTP | Gmail API / Brevo via HTTPS (seção 3.3) |
| Sistema de arquivos efêmero | Uploads em disco somem a cada deploy/restart | Comprovantes e fotos ficam **no Postgres** (`LargeBinary`) |
| **Render Postgres Free expira 30 dias após a criação** (14 dias de carência, depois os dados são apagados), 1 GB, sem backup, um banco free por workspace | Perda de dados se a renovação não for feita | **Rotina de renovação do banco** (abaixo) + backup diário |
| Armazenamento pequeno | Comprovantes podem encher o banco | Redimensionar imagem no navegador antes do upload (~200 KB), PDF até 1 MB, apagar comprovantes de cobranças aprovadas há mais de 6 meses |

**Rotina de renovação do Render Postgres Free (decisão: manter o banco no Render)**

Como só pode existir **um** banco free ativo por workspace, a troca é sequencial e tem alguns minutos de indisponibilidade. Por isso deve rodar de madrugada, longe de terça.

1. **Aviso:** a partir do dia 20 de vida do banco, o app do admin mostra o banner "Banco expira em X dias. Renovar agora". O job `tick` também envia e-mail aos admins nos dias 20, 23 e 25. A data de criação do banco fica em `Settings.dbCriadoEm`.
2. **Workflow `rotate-db.yml`** (GitHub Actions, disparo manual `workflow_dispatch` ou agendado a cada 25 dias), usando a **API REST do Render** (`RENDER_API_KEY` nos secrets; conferir os endpoints atuais na documentação da API):
   1. Coloca o app em **modo manutenção** (variável `MAINTENANCE=true` → o backend responde 503 com uma página amigável).
   2. `pg_dump -Fc` do banco atual pela **External URL** e verifica o arquivo (`pg_restore --list`).
   3. Guarda o dump criptografado (GPG) como artifact. É o mesmo formato do backup diário.
   4. Exclui o banco antigo e cria um novo banco free (mesma região do Web Service).
   5. Espera o status *available*, roda `pg_restore` e confere a contagem de linhas das tabelas principais contra o dump.
   6. Atualiza `DATABASE_URL` do Web Service com a **Internal URL** do banco novo, grava `dbCriadoEm`, tira o modo manutenção e dispara um deploy.
   7. Em caso de falha depois da exclusão, o workflow para e mantém o dump. A restauração manual fica documentada no `README` (runbook).
3. **Tempo estimado:** 5 a 10 minutos de indisponibilidade com o volume deste app.
4. **Alternativa simples:** fazer os mesmos passos à mão pelo painel do Render, seguindo o runbook (~15 min por mês).
5. **Saída futura:** se a renovação incomodar, o upgrade do banco para o plano pago mais barato (~US$ 6/mês) mantém os mesmos dados, sem migração.

**Backup (grátis):** workflow `backup.yml` no GitHub Actions rodando `pg_dump` diário, **criptografado com GPG** (o dump tem CPF e dados pessoais) e guardado como artifact (retenção de 30 dias) ou num repositório privado.

**Quando vale pagar:** se a espera para acordar incomodar o grupo, o Web Service pago de US$ 7/mês resolve, e ainda libera SMTP.
- Ambientes: `main` → produção (auto-deploy); PRs → Preview Environments (opcional).

### 9.6 CI (GitHub Actions)
- `ci.yml`: `npm ci` → `eslint` → `cds compile` → `jest` (com SQLite em memória) → `ui5 build` dos dois apps em todo PR; branch protection na `main`.
- `jobs.yml`: `schedule: '0 * * * *'` → `curl -X POST -H "X-Job-Secret: ${{ secrets.JOB_SECRET }}" $APP_URL/jobs/tick`.
- `backup.yml`: diário, `pg_dump` + GPG → artifact.
- `rotate-db.yml`: renovação do banco (seção 9.5).

---

## 10. Requisitos não funcionais, segurança, roadmap e riscos

### 10.1 Não funcionais
- Responsivo: `ResponsiveTable` nas SmartTables, `SmartForm` com `ColumnLayout`, densidade *cozy* no celular e *compact* no desktop (`sap.ui.Device`). Testar em celular, que é o uso principal.
- Idioma pt-BR (i18n), moeda BRL, fuso `America/Sao_Paulo` (armazenar em UTC).
- Tempo de resposta < 1 s nas listas com até 50 jogadores.
- Backup diário criptografado via GitHub Actions (seção 9.5).

### 10.2 Segurança e LGPD
- CPF e data de nascimento são dados pessoais: exibição mascarada, acesso completo só para admin, finalidade declarada (identificação e recuperação de senha), aceite no primeiro acesso, opção de exclusão/anonimização do jogador inativo.
- Senhas com bcrypt (custo 12); tokens de convite/reset armazenados como hash.
- Comprovantes visíveis só para o dono e para admins.
- HTTPS (nativo no Render), cookies `Secure`, `helmet`, rate limit, auditoria de ações de admin.

### 10.3 Roadmap sugerido
| Sprint | Entregas |
|---|---|
| 1 | Repo, CI, modelo de dados, AuthService (login, convite, reset), esqueleto dos dois apps freestyle (router, ToolPage, BaseController, guard), deploy Render |
| 2 | Admin: jogadores, eventos, configurações, PIX; Jogador: home, agenda/confirmação, churrasco |
| 3 | Financeiro (BR Code, QR, comprovante, aprovação), mensalidades automáticas, e-mails |
| 4 | Votação + rating, notificações no app, painel admin |
| 5 | Extras da Fase 1, testes de ponta a ponta, piloto com o grupo |

### 10.4 Riscos
| Risco | Mitigação |
|---|---|
| `sap.ui.comp` (smart controls) sem evolução pela SAP | Biblioteca estável e suportada; anotações CDS reaproveitáveis numa futura migração para `sap.ui.mdc` (decisão D1) |
| Mais código de UI que no Fiori Elements (controllers, rotas, edição) | `BaseController` e utilitários comuns em `app/common`; padrões fixos da seção 6.0 |
| Smart controls dependem de anotações bem feitas | Arquivo de anotações por entidade em `srv/annotations/`, revisado junto com cada view |
| Mistura de smart controls com controles visuais deixar a interface inconsistente | Catálogo fechado da seção 6.0.1; tema único Horizon com CSS de marca em `app/common` |
| `sap.suite.ui.microchart` é biblioteca adicional | Opcional; `ProgressIndicator` (sap.m) cobre o caso de vagas |
| Aprovação manual de PIX vira gargalo | Aprovação em lote; Fase 3 com PSP e webhook |
| Hibernação do Web Service gratuito | Keep-alive; plano de US$ 7/mês se incomodar |
| Expiração do Render Postgres Free (30 dias) | Workflow `rotate-db.yml`, avisos a partir do dia 20, backup diário criptografado, runbook de restauração; upgrade para o plano pago como saída |
| Refresh token do Gmail revogado/expirado | App OAuth publicado "Em produção"; alerta no log/admin se o envio falhar; plano B Brevo por variável de ambiente |
| E-mails caindo no spam | Envio pela API do próprio Gmail; pedir aos jogadores que marquem como "não é spam" no primeiro convite |
| Convidados lotando vagas | Limite por jogador e prioridade dos jogadores do grupo até o prazo |
| Baixa adesão à votação | Lembrete por notificação, badge no menu, janela curta (48h) |

---

### Fontes
- [Chega+ na App Store](https://apps.apple.com/BR/app/id1084859198) · [Chega+ (resumo da listagem e avaliações)](https://mwm.ai/pt/apps/chega/1084859198)
- [Pelada+](https://apps.apple.com/vg/app/pelada/id1637292238) · [FutMatch](https://apps.apple.com/us/app/futmatch/id6754748640) · [Futebol Society](https://mwm.ai/apps/futebol-society/6743960382) · [Sorteio de Times – Futebol](https://apps.apple.com/us/app/-/id6478060840) · [Futbora (TabNews)](https://www.tabnews.com.br/YuryVidal/pitch-futbora-seu-futebol-organizado-2022)
- [CAP – Using PostgreSQL](https://cap.cloud.sap/docs/guides/databases/postgres)
