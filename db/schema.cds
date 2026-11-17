namespace futebol;

using {
    cuid,
    managed,
} from '@sap/cds/common';

type PlayerStatus : String(10) enum {
    @title: 'Invited' INVITED;
    @title: 'Active' ACTIVE;
    @title: 'Inactive' INACTIVE;
}

type PlayerTypes  : String(10) enum {
    @title: 'Monthly' MONTHLY;
    @title: 'Drop-in' DROP_IN;
} // MONTHLY, DROP_IN

type Positions : String(10) enum {
    @title: 'Goalkeeper' GOALKEEPER;
    @title: 'Outfield' OUTFIELD;
}

type FieldRoles : String(10) enum {
    @title: 'Defense' DEFENSE;
    @title: 'Midfield' MIDFIELD;
    @title: 'Attack' ATTACK;
} // DEFENSE, MIDFIELD, ATTACK (posição preferida na linha, opcional)

type DrawModes : String(12) enum {
    @title: 'Balanced' BALANCED;
    @title: 'Random' RANDOM;
    @title: 'First Come' FIRST_COME;
    @title: 'Captains' CAPTAINS;
}

type GoalStatus : String(10) enum {
    @title: 'Valid' VALID;
    @title: 'Pending' PENDING;
    @title: 'Disputed' DISPUTED;
    @title: 'Rejected' REJECTED;
}

type EventCategories : String(10) enum {
    @title: 'Match' MATCH;
    @title: 'Social' SOCIAL;
}

type ChargeModes : String(12) enum {
    @title: 'Game Fee' GAME_FEE;
    @title: 'Split' SPLIT;
    @title: 'Free' FREE;
} // GAME_FEE, SPLIT, FREE

type EventStatus : String(10) enum {
    @title: 'Draft' DRAFT;
    @title: 'Open' OPEN;
    @title: 'Closed' CLOSED;
    @title: 'Completed' COMPLETED;
    @title: 'Cancelled' CANCELLED;
}

type AttendanceStatus : String(10) enum {
    @title: 'Pending' PENDING;
    @title: 'Confirmed' CONFIRMED;
    @title: 'Declined' DECLINED;
    @title: 'Waitlist' WAITLIST;
}

type ChargeTypes : String(12) enum {
    @title: 'Monthly Fee' MONTHLY_FEE;
    @title: 'Per Game' PER_GAME;
    @title: 'Event' EVENT;
    @title: 'Other' OTHER;
}

type ChargeStatus : String(10) enum {
    @title: 'Pending' PENDING;
    @title: 'Reported' REPORTED;
    @title: 'Approved' APPROVED;
    @title: 'Rejected' REJECTED;
    @title: 'Cancelled' CANCELLED;
}

type PixKeyTypes : String(10) enum {
    @title: 'CPF' CPF;
    @title: 'CNPJ' CNPJ;
    @title: 'EMAIL' EMAIL;
    @title: 'PHONE' PHONE;
    @title: 'RANDOM' RANDOM;
} // CPF, CNPJ, EMAIL, PHONE, RANDOM

entity Players : cuid, managed {
    fullName             : String(120) not null;
    nickname             : String(40);
    email                : String(120) not null; // unique
    cpf                  : String(11) not null; // unique, validado (dígitos verificadores)
    birthDate            : Date not null;
    phone                : String(20);
    photo                : LargeBinary   @Core.MediaType: photoMimeType;
    photoMimeType        : String        @Core.IsMediaType;
    position             : Positions;
    fieldRole            : FieldRoles; // preferida: defesa, meio, ataque (opcional)
    initialRating        : Decimal(3, 2); // força inicial do novato, definida pelo admin
    playerType           : PlayerTypes default 'MONTHLY';
    status               : PlayerStatus default 'INVITED';
    isAdmin              : Boolean default false;
    passwordHash         : String(100)   @Core.Computed; // nunca exposto
    mustChangePassword   : Boolean default false;
    loginAttempts        : Integer default 0;
    lockedUntil          : Timestamp;
    lgpdAcceptedAt       : Timestamp;
    rating               : Decimal(3, 2) @Core.Computed; // média calculada (seção 5.4)
    absences             : Integer       @Core.Computed; // usado só se trackAbsences = true
    suspendedUntil       : Date; // usado só se suspendForAbsences = true
    acceptedTermsVersion : Integer;
    totalGames           : Integer       @Core.Computed;
    attendances          : Association to many Attendances
                               on attendances.player = $self;
    charges              : Association to many Charges
                               on charges.player = $self;
}

entity Invitations : cuid, managed {
    player     : Association to Players;
    tokenHash  : String(100);
    expiresAt  : Timestamp;
    acceptedAt : Timestamp;
}

entity PasswordResets : cuid {
    player    : Association to Players;
    tokenHash : String(100);
    expiresAt : Timestamp;
    usedAt    : Timestamp;
} // ---------- Configuração ----------

entity PixKeys : cuid, managed {
    description  : String(60);
    keyType      : PixKeyTypes;
    keyValue     : String(77);
    receiverName : String(25); // limite do BR Code
    city         : String(15); // limite do BR Code
    active       : Boolean default true;
}

@cds.singleton // uma única linha; campos agrupados por @UI.FieldGroup (ver seção 7.0)
entity Settings : managed {
    key ID                          : Integer default 1;
        // Geral
        groupName                   : String(60);
        logo                        : LargeBinary @Core.MediaType: logoMimeType;
        logoMimeType                : String      @Core.IsMediaType;
        accentColor                 : String(7);
        defaultWeekday              : Integer;
        defaultTime                 : Time;
        durationMin                 : Integer;
        defaultLocation             : String(120);
        // Agenda automática
        autoSchedule                : Boolean;
        weeksAhead                  : Integer;
        autoPublish                 : Boolean;
        barbecueWithGame            : Boolean;
        // Presença
        defaultOutfieldSlots        : Integer;
        defaultGoalkeeperSlots      : Integer;
        confirmationDeadlineHours   : Integer;
        allowConfirmAfterDeadline   : Boolean;
        autoWaitlist                : Boolean;
        allowWithdrawAfterDeadline  : Boolean;
        allowBarbecueOnly           : Boolean;
        suggestBarbecue             : Boolean;
        // Convidados
        guestsInGames               : Boolean;
        guestsInBarbecue            : Boolean;
        maxGuestsPerPlayer          : Integer;
        guestsOnlyAfterDeadline     : Boolean;
        guestGameFee                : Decimal(9, 2);
        guestBarbecueFee            : Decimal(9, 2);
        chargeHost                  : Boolean;
        // Financeiro
        monthlyFee                  : Decimal(9, 2);
        dropInGameFee               : Decimal(9, 2);
        defaultBarbecueFee          : Decimal(9, 2);
        dueDay                      : Integer;
        autoGenerateMonthlyFees     : Boolean;
        monthlyFeeGenerationDay     : Integer;
        paymentDeadlineDays         : Integer;
        monthlyFeePix               : Association to PixKeys;
        gameFeePix                  : Association to PixKeys;
        defaultBarbecuePix          : Association to PixKeys;
        requireReceipt              : Boolean;
        receiptRetentionMonths      : Integer;
        // Inadimplência (bloqueio/multa desligados por padrão)
        dueReminders                : Boolean;
        remindDaysBefore            : Integer;
        remindEveryDaysAfter        : Integer;
        blockDelinquent             : Boolean;
        blockGraceDays              : Integer;
        blockMinAmount              : Decimal(9, 2);
        blockBarbecue               : Boolean;
        blockVoting                 : Boolean;
        lateFee                     : Boolean;
        lateFeeType                 : String(1) /* P=percentual F=valor fixo */;
        lateFeeAmount               : Decimal(9, 2);
        showGroupPendingCharges     : Boolean;
        // Faltas
        trackAbsences               : Boolean;
        withdrawWithoutAbsenceHours : Integer;
        absenceFee                  : Boolean;
        absenceFeeAmount            : Decimal(9, 2);
        suspendForAbsences          : Boolean;
        absencesToSuspend           : Integer;
        suspensionGames             : Integer;
        // Votação
        votingEnabled               : Boolean;
        openVotingHoursAfter        : Integer;
        votingWindowHours           : Integer;
        anonymousVotes              : Boolean;
        mvpEnabled                  : Boolean;
        minGamesForRating           : Integer;
        ratingMethod                : String(10) /* GAME_AVG, SIMPLE, LAST_N */;
        lastNGames                  : Integer;
        ratingVisibility            : String(10) /* ALL, OWN */;
        // Dia do jogo / sorteio de times
        whoDraws                    : String(12) /* ADMIN, ORGANIZER, CONFIRMED */;
        selfCheckin                 : Boolean;
        checkinMinBefore            : Integer;
        checkinMinAfter             : Integer;
        drawMode                    : DrawModes;
        outfieldPlayersPerTeam      : Integer;
        goalkeepersPerTeam          : Integer;
        autoTeamCount               : Boolean;
        fixedTeamCount              : Integer;
        leftoverPlayers             : String(12) /* WAIT_TEAM, DISTRIBUTE */;
        noGoalkeeper                : String(12) /* ROTATION, NONE */;
        bibColors                   : String(200);
        defaultNewcomerRating       : Decimal(3, 2);
        strengthLastNGames          : Integer;
        statsWeight                 : Decimal(3, 2);
        balancePositions            : Boolean;
        avoidRepeatPairs            : Boolean;
        pairMemoryGames             : Integer;
        drawSolutions               : Integer;
        drawTolerancePct            : Decimal(5, 2);
        latecomerGoesTo             : String(12) /* WAITLIST, WEAKEST */;
        // Artilharia e assistências
        statsEnabled                : Boolean;
        whoRecordsGoals             : String(12) /* SELF, PARTICIPANTS, ORGANIZER */;
        goalValidation              : String(12) /* AUTOMATIC, TEAMMATE, ADMIN */;
        disputeHours                : Integer;
        maxGoalsPerGame             : Integer;
        trackOwnGoals               : Boolean;
        trackMatches                : Boolean;
        seasonStart                 : Date;
        rankingTiebreaker           : String(30);
        // Notificações
        confirmationReminderHours   : Integer;
        quietHoursStart             : Time;
        quietHoursEnd               : Time;
        // Segurança
        maxLoginAttempts            : Integer;
        loginLockMinutes            : Integer;
        inviteValidityDays          : Integer;
        resetValidityMinutes        : Integer;
        sessionDays                 : Integer;
        minPasswordLength           : Integer;
        // Privacidade
        termsText                   : LargeString;
        termsVersion                : Integer;
        requireReacceptance         : Boolean;
        // Infra (somente leitura na tela)
        dbCreatedAt                 : Date;
}
// Os padrões ficam em db/data/futebol-Settings.csv (seção 7.0), não no código.

entity NotificationRules : cuid { // matriz tipo de aviso x canal
    notificationType : String(30); // NEW_EVENT, CONFIRMATION_REMINDER, CHARGE, PAYMENT_APPROVED, VOTING_OPEN, PROMOTED_FROM_WAITLIST...
    inApp            : Boolean default true;
    email            : Boolean default false;
}

entity EmailTemplates : cuid, managed {
    templateType : String(30);
    subject      : String(150);
    body         : LargeString; // HTML com variáveis {{name}}, {{date}}, {{amount}}, {{link}}
}

// ---------- Eventos ----------
// Tipos de evento cadastráveis pelo admin (seção 7.0.1)
entity EventTypes : cuid, managed {
    name                      : String(60) not null; // "Jogo de terça", "Churrasco", "Confraternização de fim de ano"
    category                  : EventCategories not null; // MATCH tem vagas linha/goleiro e votação
    icon                      : String(40); // sap-icon://...
    color                     : String(7);
    defaultChargeMode         : ChargeModes default 'PER_PERSON';
    defaultPixKey             : Association to PixKeys;
    allowGuests               : Boolean default true;
    defaultMaxGuests          : Integer;
    limitSlots                : Boolean default false;
    defaultSlots              : Integer;
    confirmationDeadlineHours : Integer;
    paymentDeadlineDays       : Integer;
    active                    : Boolean default true;
    defaultPrices             : Composition of many EventTypePrices
                                    on defaultPrices.eventType = $self;
}

entity EventTypePrices : cuid { // faixas padrão do tipo
    eventType   : Association to EventTypes;
    description : String(40); // Jogador, Convidado, Criança até 12...
    amount      : Decimal(9, 2);
    forGuest    : Boolean default false;
    sortOrder   : Integer;
}

entity Events : cuid, managed {
    eventType            : Association to EventTypes not null;
    title                : String(80);
    description          : String(1000);
    cover                : LargeBinary   @Core.MediaType: coverMimeType;
    coverMimeType        : String        @Core.IsMediaType;
    eventDate            : Date not null;
    startTime            : Time;
    endTime              : Time;
    location             : String(120);
    status               : EventStatus default 'DRAFT';
    outfieldSlots        : Integer;
    goalkeeperSlots      : Integer;
    confirmationDeadline : Timestamp;
    slots                : Integer; // eventos sociais com limite (opcional)
    chargeMode           : ChargeModes; // copiado do tipo, editável
    totalCost            : Decimal(9, 2); // usado no SPLIT
    splitAmount          : Decimal(9, 2) @Core.Computed; // calculado ao fechar a lista
    pixKey               : Association to PixKeys; // chave do evento (copiada do tipo)
    paymentDeadline      : Date;
    maxGuests            : Integer;
    audience             : String(12) default 'ALL'; // ALL, MONTHLY, SELECTED
    organizer            : Association to Players; // organizador do dia (check-in e sorteio)
    teamsPublished       : Boolean default false;
    linkedGame           : Association to Events; // vínculo opcional com o jogo do dia
    linkedEvents         : Association to many Events
                               on linkedEvents.linkedGame = $self;
    prices               : Composition of many EventPrices
                               on prices.event = $self;
    votingOpenUntil      : Timestamp;
    score                : String(20);
    notes                : String(500);
    attendances          : Composition of many Attendances
                               on attendances.event = $self;
    charges              : Association to many Charges
                               on charges.event = $self;
    votes                : Association to many Votes
                               on votes.event = $self;
}

entity Attendances : cuid, managed {
    event              : Association to Events not null;
    player             : Association to Players; // jogador cadastrado (nulo se for convidado)
    guest              : Association to Guests; // convidado (nulo se for jogador)
    status             : AttendanceStatus default 'PENDING';
    position           : Positions; // goleiro/linha (para vagas)
    waitlistPosition   : Integer; // lista de espera
    respondedAt        : Timestamp;
    present            : Boolean; // check-in no dia (opcional, só estatística)
    arrivalOrder       : Integer; // check-in no dia
    checkedInAt        : Timestamp;
    team               : Association to Teams; // time do sorteio publicado
    rotatingGoalkeeper : Boolean default false;
// gols/assistências: calculados a partir de Goals (view PlayerStats)
}
// unique (event, player) e (event, guest); exatamente um de player/guest preenchido
// + priceTier : Association to EventPrices  (faixa escolhida: Jogador, Convidado, Criança...)

entity EventPrices : cuid { // faixas de preço do evento (copiadas do tipo, editáveis)
    event       : Association to Events;
    description : String(40);
    amount      : Decimal(9, 2);
    forGuest    : Boolean default false;
    sortOrder   : Integer;
}

// ---------- Convidados ----------
entity Guests : cuid, managed {
    name      : String(120) not null;
    phone     : String(20);
    invitedBy : Association to Players not null; // responsável pela cobrança
    position  : Positions;
}

// ---------- Dia do jogo: sorteio ----------
entity Teams : cuid {
    event         : Association to Events;
    number        : Integer; // 1, 2, 3 (3 = time de espera, se houver)
    name          : String(30); // "Time Laranja"
    color         : String(20); // cor do colete
    totalStrength : Decimal(6, 2);
    avgStrength   : Decimal(4, 2);
    standby       : Boolean default false;
    members       : Association to many Attendances
                        on members.team = $self;
}

entity DrawLogs : cuid, managed {
    event      : Association to Events;
    drawNumber : Integer; // 1º, 2º... (resorteios ficam visíveis)
    mode       : DrawModes;
    seed       : String(32);
    parameters : LargeString; // JSON com a configuração usada
    result     : LargeString; // JSON com times e forças
    balancePct : Decimal(5, 2);
    published  : Boolean default false;
}

entity DrawConstraints : cuid, managed { // restrições opcionais do sorteio
    playerA        : Association to Players;
    playerB        : Association to Players;
    constraintType : String(10); // TOGETHER, APART
    active         : Boolean default true;
}

entity Matches : cuid, managed { // opcional: partidas da noite
    event  : Association to Events;
    number : Integer;
    teamA  : Association to Teams;
    teamB  : Association to Teams;
    goalsA : Integer;
    goalsB : Integer;
}

// ---------- Artilharia e assistências ----------
entity Goals : cuid, managed {
    event         : Association to Events not null;
    match         : Association to Matches; // opcional
    scorer        : Association to Attendances; // jogador ou convidado que marcou (nulo se gol contra)
    assistant     : Association to Attendances; // quem deu a assistência (opcional)
    team          : Association to Teams;
    ownGoal       : Boolean default false;
    recordedBy    : Association to Players;
    status        : GoalStatus default 'VALID';
    disputedBy    : Association to Players;
    disputeReason : String(200);
}
// view PlayerStats: gols, assistências, G+A, jogos, média por jogo, por período/temporada

// ---------- Financeiro ----------
entity Charges : cuid, managed {
    player          : Association to Players not null;
    chargeType      : ChargeTypes not null;
    referenceMonth  : String(7); // AAAA-MM (mensalidade)
    event           : Association to Events; // churrasco / diária
    description     : String(120);
    amount          : Decimal(9, 2) not null;
    dueDate         : Date;
    status          : ChargeStatus default 'PENDING';
    pixKey          : Association to PixKeys;
    txid            : String(25);
    pixCopyPaste    : LargeString @Core.Computed;
    qrCodeUrl       : String      @Core.Computed  @UI.IsImageURL;
    receipt         : LargeBinary @Core.MediaType: receiptMimeType;
    receiptMimeType : String      @Core.IsMediaType;
    reportedAt      : Timestamp;
    approvedBy      : Association to Players;
    approvedAt      : Timestamp;
    rejectionReason : String(200);
}

entity Expenses : cuid, managed { // caixa do grupo (extra)
    expenseDate        : Date;
    description        : String(120);
    category           : String(30); // COURT, BALL, BIBS, BARBECUE, OTHER
    amount             : Decimal(9, 2);
    event              : Association to Events;
    attachment         : LargeBinary @Core.MediaType: attachmentMimeType;
    attachmentMimeType : String      @Core.IsMediaType;
}

// ---------- Votação ----------
entity Votes : cuid, managed {
    event       : Association to Events not null;
    voter       : Association to Players not null;
    ratedPlayer : Association to Players not null;
    rating      : Integer @assert.range: [
        1,
        5
    ];
    mvp         : Boolean default false; // "craque da partida" (1 por eleitor)
}
// unique (event, voter, ratedPlayer); voter != ratedPlayer

// ---------- Notificações / auditoria ----------
entity Notifications : cuid, managed {
    player : Association to Players;
    title  : String(80);
    text   : String(300);
    link   : String(200); // rota interna do app (hash do router)
    isRead : Boolean default false;
}

entity AuditLog : cuid, managed {
    action     : String(40); // APPROVE_PAYMENT, RESET_PASSWORD, MAKE_ADMIN...
    entityName : String(40);
    entityKey  : String(36);
    details    : LargeString;
}
