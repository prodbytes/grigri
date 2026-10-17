// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get disciplineSport => 'Esportiva';

  @override
  String get disciplineTrad => 'Tradicional';

  @override
  String get disciplineBouldering => 'Boulder';

  @override
  String get disciplineGym => 'Academia';

  @override
  String get gradeSystemEuropean => 'Europeu';

  @override
  String get gradeSystemAmerican => 'Americano';

  @override
  String get gearRope => 'Corda';

  @override
  String get gearQuickdraws => 'Costuras';

  @override
  String get gearRack => 'Móveis';

  @override
  String get gearCrashPad => 'Crash pad';

  @override
  String get gearCar => 'Carro';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get more => 'Mais';

  @override
  String get refresh => 'Atualizar';

  @override
  String get signOut => 'Sair';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get newPlan => 'Novo plano';

  @override
  String get you => 'Você';

  @override
  String get youLower => 'você';

  @override
  String get someone => 'Alguém';

  @override
  String climberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count escaladores',
      one: '1 escalador',
    );
    return '$_temp0';
  }

  @override
  String saidYesCount(int yes, int total) {
    return '$yes de $total disseram sim';
  }

  @override
  String get declined => 'Recusado';

  @override
  String get pending => 'Pendente';

  @override
  String get accept => 'Aceitar';

  @override
  String get decline => 'Recusar';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get errorGeneric => 'Deu algo errado.';

  @override
  String errorStatus(int status) {
    return 'Deu algo errado ($status).';
  }

  @override
  String get errorTimeout => 'O servidor demorou demais para responder.';

  @override
  String get errorUnreachable => 'Não foi possível conectar ao servidor.';

  @override
  String get errorPhotoTimeout => 'O envio da foto demorou demais.';

  @override
  String get errorPhotoUnreachable => 'Não foi possível enviar a foto.';

  @override
  String errorPhotoStatus(int status) {
    return 'O envio da foto falhou ($status).';
  }

  @override
  String get errorPhotoType => 'Use uma foto JPEG, PNG ou WebP.';

  @override
  String get errorSignedOut => 'Você saiu da conta: entre de novo.';

  @override
  String get errorSignIn =>
      'Não foi possível entrar com o Google. Tente de novo.';

  @override
  String get errorSignInApple =>
      'Não foi possível entrar com a Apple. Tente de novo.';

  @override
  String get errorSession => 'Não foi possível entrar. Tente de novo.';

  @override
  String get errorSignOutEverywhere =>
      'Não foi possível sair de todos os dispositivos. Tente de novo.';

  @override
  String get loadFailedTitle => 'Não foi possível carregar seu perfil';

  @override
  String get signInTagline =>
      'Crie um plano ou deslize para a direita em um, e escalem juntos.';

  @override
  String get signInWithGoogle => 'Entrar com o Google';

  @override
  String get signInWithApple => 'Iniciar sessão com a Apple';

  @override
  String get tabDiscover => 'Buscar';

  @override
  String get tabPlans => 'Planos';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabNotifications => 'Avisos';

  @override
  String get tabProfile => 'Eu';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'O plano';

  @override
  String get demoTag => 'Demo';

  @override
  String get demoNotice => 'Demo: pessoas e planos fictícios.';

  @override
  String get yourGrades => 'Seu grau';

  @override
  String get profileClimbs => 'Escala';

  @override
  String get profileGear => 'Equipamento';

  @override
  String gearPhotoOf(String name, int number) {
    return 'Equipamento de $name, foto $number';
  }

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Idioma do sistema';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get signOutQuestion => 'Sair?';

  @override
  String get signOutMessage =>
      'Seu perfil, planos e conversas continuam salvos; entre de novo para vê-los.';

  @override
  String get signOutEverywhere => 'Sair de todos os dispositivos';

  @override
  String get signOutEverywhereQuestion => 'Sair de todos os dispositivos?';

  @override
  String get signOutEverywhereMessage =>
      'Encerra sua sessão em todos os celulares e navegadores em que você entrou, incluindo este. Seu perfil, planos e conversas continuam salvos.';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get profileFootnote =>
      'Seu perfil é sobre você: o que você escala e o equipamento que tem. O quando e o onde ficam para os planos, criados à parte em Planos.';

  @override
  String get takePhoto => 'Tirar uma foto';

  @override
  String get choosePhoto => 'Escolher uma foto';

  @override
  String get removePhoto => 'Remover a foto';

  @override
  String get photoFailed => 'Não foi possível pegar essa foto';

  @override
  String get addPhoto => 'Adicionar uma foto';

  @override
  String get changePhoto => 'Trocar sua foto';

  @override
  String get nameLabel => 'Nome';

  @override
  String get nameRequired => 'Seu nome, por favor';

  @override
  String get ageLabel => 'Idade (opcional)';

  @override
  String ageRange(int min, int max) {
    return 'De $min a $max';
  }

  @override
  String get bioLabel => 'Sobre você';

  @override
  String get gradeSystem => 'Sistema de graduação';

  @override
  String get gradeSystemHint =>
      'Como os graus aparecem no app, aqui para uma via e um boulder.';

  @override
  String get whatYouClimb => 'O que você escala';

  @override
  String get whatYouClimbHint =>
      'Escolha suas modalidades e os graus que você escala.';

  @override
  String get gearYouCanBring => 'Equipamento que você pode levar';

  @override
  String get gearHint => 'Adicione fotos dele também.';

  @override
  String gearPhoto(int number) {
    return 'Foto do equipamento $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Remover a foto do equipamento $number';
  }

  @override
  String get addGearPhoto => 'Adicionar uma foto do equipamento';

  @override
  String get whereYouClimb => 'Onde você escala';

  @override
  String get whereYouClimbHint =>
      'Planos perto daqui aparecem primeiro em Descobrir. Só você vê isso.';

  @override
  String get setYourLocation => 'Defina sua localização';

  @override
  String get yourLocation => 'Sua localização';

  @override
  String get clearYourLocation => 'Apagar sua localização';

  @override
  String removeArea(String name) {
    return 'Remover $name';
  }

  @override
  String get addArea => 'Adicionar uma região';

  @override
  String get locationSearchLabel => 'Um pico ou academia perto de lá';

  @override
  String get search => 'Buscar';

  @override
  String get locationPrivacy =>
      'Guardada com precisão de cerca de 1 km, e só você vê.';

  @override
  String placesAttribution(String attribution) {
    return 'Locais: $attribution';
  }

  @override
  String get loadingPlaces => 'Carregando locais…';

  @override
  String get noPlacesFound => 'Nenhum local encontrado';

  @override
  String get useCurrentLocation => 'Usar minha localização atual';

  @override
  String get locationNotFound =>
      'Não foi possível saber onde você está. Busque um local.';

  @override
  String nearPlace(String place) {
    return 'Perto de $place';
  }

  @override
  String get currentLocation => 'Onde estou';

  @override
  String get setWhereYouClimbHint =>
      'Defina onde você escala para ver primeiro os planos perto de você.';

  @override
  String get setAction => 'Definir';

  @override
  String get discoverTitle => 'Descobrir planos';

  @override
  String get askedToJoinSent =>
      'Pedido enviado. Você vai receber um aviso quando aceitarem você.';

  @override
  String get noPlansToJoinTitle => 'Nenhum plano para entrar agora';

  @override
  String get noPlansToJoinMessage =>
      'Ninguém tem um plano aberto para você ainda. Crie o seu: escaladores compatíveis vão pedir para entrar.';

  @override
  String get swipeJoin => 'Entrar';

  @override
  String get swipePass => 'Passar';

  @override
  String get pass => 'Passar';

  @override
  String get askToJoin => 'Pedir para entrar';

  @override
  String get sharePlan => 'Compartilhar este plano';

  @override
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  ) {
    return 'Plano de escalada no Grigri: $discipline em $place, $when. $link';
  }

  @override
  String get organizedBy => 'Organizado por';

  @override
  String get alsoInGroup => 'Também no grupo';

  @override
  String get showGroup => 'Ver o grupo';

  @override
  String get hideGroup => 'Ocultar o grupo';

  @override
  String get chatsTitle => 'Conversas';

  @override
  String get noChatsTitle => 'Nenhuma conversa ainda';

  @override
  String get noChatsMessage =>
      'Cada plano em que você está tem uma conversa em grupo. Crie um plano, ou peça para entrar em um, e a conversa aparece aqui.';

  @override
  String get findPlan => 'Encontrar um plano';

  @override
  String messagePreview(String author, String text) {
    return '$author: $text';
  }

  @override
  String toAnswer(int count) {
    return '$count para responder';
  }

  @override
  String get notInGroupTitle => 'Você não está neste grupo';

  @override
  String get notInGroupMessage =>
      'Você saiu deste plano, então a conversa está fechada.';

  @override
  String get messageHint => 'Escreva para o grupo';

  @override
  String get send => 'Enviar';

  @override
  String get wantsToJoinYourAnswer => 'Quer entrar · sua resposta';

  @override
  String declineName(String name) {
    return 'Recusar $name';
  }

  @override
  String acceptName(String name) {
    return 'Aceitar $name';
  }

  @override
  String askedToJoinAt(String time) {
    return 'Pediu para entrar · $time';
  }

  @override
  String noGradesYet(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Ainda sem grau em esportiva',
      'trad': 'Ainda sem grau em tradicional',
      'bouldering': 'Ainda sem grau em boulder',
      'gym': 'Ainda sem grau em academia',
      'other': 'Ainda sem grau',
    });
    return '$_temp0';
  }

  @override
  String get joined => 'Entrou';

  @override
  String get closed => 'Fechado';

  @override
  String namesSaidYes(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Disseram sim: $names',
      one: 'Disse sim: $names',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'falta $names';
  }

  @override
  String get itsAMatch => 'Deu match!';

  @override
  String get matchEveryoneSaidYes =>
      'O grupo todo disse sim. Vocês vão escalar juntos:';

  @override
  String matchJoinsGroup(String name) {
    return '$name entra no grupo:';
  }

  @override
  String get openGroupChat => 'Abrir a conversa do grupo';

  @override
  String get keepSwiping => 'Continuar deslizando';

  @override
  String get notificationsTitle => 'Avisos';

  @override
  String get nothingYetTitle => 'Nada ainda';

  @override
  String get nothingYetMessage =>
      'Quando alguém pedir para entrar em um plano em que você está, ou um grupo responder ao seu pedido, você fica sabendo aqui.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name quer entrar';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · responda na conversa do grupo';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'Você entrou: $plan';
  }

  @override
  String get noticeAcceptedBody =>
      'O grupo aceitou você. Dê um oi na conversa.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Dessa vez não: $plan';
  }

  @override
  String get noticeDeclinedBody => 'O grupo recusou seu pedido.';

  @override
  String get newTag => 'Novo';

  @override
  String get planGoneTitle => 'Esse plano não existe mais';

  @override
  String get planGoneMessage =>
      'Todo mundo saiu deste plano, ou ele não está mais aberto.';

  @override
  String get yourPlan => 'Seu plano';

  @override
  String get planTitle => 'Plano';

  @override
  String get edit => 'Editar';

  @override
  String get declinedGroupSaidNo => 'Recusado: o grupo disse não';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'Pendente: $yes de $total disseram sim';
  }

  @override
  String theGroupCount(int count) {
    return 'O grupo · $count';
  }

  @override
  String get organizer => 'Organizador';

  @override
  String get member => 'Membro';

  @override
  String get askingToJoin => 'Pedidos para entrar';

  @override
  String get youSaidYes => 'Você disse sim';

  @override
  String get answerInChat => 'Responda na conversa';

  @override
  String get groupChat => 'Conversa do grupo';

  @override
  String get cancelPlan => 'Cancelar o plano';

  @override
  String get cancelPlanQuestion => 'Cancelar o plano?';

  @override
  String get cancelPlanMessage => 'O plano e a conversa vão sumir.';

  @override
  String get cancelPlanOthersMessage =>
      'Ele sai dos seus planos e conversas; os outros continuam com ele. Você não vai poder entrar de novo.';

  @override
  String get cancelPlanOrganizerMessage =>
      'Ele sai dos seus planos e conversas; os outros continuam com ele, e um deles, sorteado, vai organizar. Você não vai poder entrar de novo.';

  @override
  String get keepPlan => 'Manter';

  @override
  String get confirmCancelPlan => 'Cancelar';

  @override
  String get editPlan => 'Editar plano';

  @override
  String get pickFutureTime => 'Escolha um horário que ainda não passou.';

  @override
  String get sectorLabel => 'Setor, pico ou academia';

  @override
  String get sectorHint => 'Busque ou digite';

  @override
  String sectorsAttribution(String attribution) {
    return 'Setores: $attribution';
  }

  @override
  String get whereRequired => 'Onde você vai escalar?';

  @override
  String get sectionDiscipline => 'Escalada';

  @override
  String get sectionWhere => 'Onde';

  @override
  String get sectionWhen => 'Quando';

  @override
  String get dateToBeDecided => 'Data a definir';

  @override
  String dayAndMoreDays(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$day +$_temp0';
  }

  @override
  String get addDay => 'Adicionar um dia';

  @override
  String get leaveDateOpen => 'Deixar a data em aberto';

  @override
  String get whenHelp =>
      'A data é opcional. Adicione mais dias para uma saída mais longa.';

  @override
  String get sectionGrades => 'Graus';

  @override
  String get sectionNotes => 'Observações';

  @override
  String get notesHint =>
      'Ponto de encontro, vagas no carro, as vias que você tem em mente…';

  @override
  String get publishPlan => 'Publicar o plano';

  @override
  String get yourPlans => 'Seus planos';

  @override
  String get noPlansYetTitle => 'Nenhum plano ainda';

  @override
  String get noPlansYetMessage =>
      'Crie um plano (o quê, onde, quando) e escaladores compatíveis vão pedir para entrar. Ou deslize para a direita em um em Descobrir.';

  @override
  String get plansClimbing => 'Escalando';

  @override
  String get plansAskedToJoin => 'Pedidos';

  @override
  String get organizing => 'Você organiza';

  @override
  String get accepted => 'Aceito';

  @override
  String toReview(int count) {
    return '$count para revisar';
  }

  @override
  String get groupSaidNo => 'O grupo disse não';

  @override
  String waitingForNames(String names) {
    return 'Esperando $names';
  }

  @override
  String get dismiss => 'Dispensar';

  @override
  String get adminTitle => 'Admin: pessoas';

  @override
  String get roles => 'Funções';

  @override
  String get rolesFailed => 'Não foi possível buscar suas funções no rbacr.';

  @override
  String get noRoles => 'Nenhuma função no Grigri ainda.';

  @override
  String get nudge => 'Lembrar';

  @override
  String get nudged => 'Lembrado';

  @override
  String get nudgeTooltip =>
      'Lembre o grupo de responder (uma vez a cada 12 horas)';

  @override
  String nudgeSent(String names) {
    return 'Lembrete enviado para $names';
  }

  @override
  String noticeNudgeTitle(String name) {
    return '$name está esperando sua resposta';
  }

  @override
  String noticeNudgeBody(String plan) {
    return 'Para entrar em $plan · aceite ou recuse na conversa do grupo';
  }

  @override
  String get attachMedia => 'Adicionar uma foto ou um vídeo';

  @override
  String get recordVideo => 'Gravar um vídeo';

  @override
  String get chooseVideo => 'Escolher um vídeo';

  @override
  String get photoMessage => 'Foto';

  @override
  String get videoMessage => 'Vídeo';

  @override
  String get removeAttachment => 'Remover o anexo';

  @override
  String get uploadingMedia => 'Enviando…';

  @override
  String get playVideo => 'Reproduzir o vídeo';

  @override
  String get videoUnavailable => 'Não é possível reproduzir este vídeo.';

  @override
  String get mediaUnavailable => 'Indisponível';

  @override
  String get errorMediaType =>
      'Use uma foto JPEG, PNG ou WebP, ou um vídeo MP4 ou MOV.';

  @override
  String errorVideoTooBig(int mb) {
    return 'Os vídeos podem ter no máximo $mb MB: envie um mais curto.';
  }

  @override
  String matchScore(int percent, String level) {
    return 'Afinidade $percent% · $level';
  }

  @override
  String get matchLevelLongShot => 'improvável';

  @override
  String get matchLevelPossible => 'possível';

  @override
  String get matchLevelGood => 'boa';

  @override
  String get matchLevelGreat => 'ótima';

  @override
  String get matchReasonOtherDiscipline => 'Você não escala essa modalidade';

  @override
  String get matchReasonTooHard => 'As graduações estão bem acima das suas';

  @override
  String get matchReasonTooEasy => 'As graduações estão bem abaixo das suas';

  @override
  String get matchReasonStartsSoon => 'Começa em menos de 12 horas';

  @override
  String get matchReasonFar => 'A mais de 100 km';

  @override
  String get matchReasonBigGroup => 'Cinco ou mais pessoas precisam dizer sim';

  @override
  String get matchReasonCrowded => 'Dez ou mais pessoas estão esperando';

  @override
  String get matchReasonInGradesNearby => 'Nas suas graduações e perto';

  @override
  String get matchReasonInGrades => 'Nas suas graduações';

  @override
  String get matchReasonCloseGrades => 'A uma ou duas graduações das suas';

  @override
  String get adminNoClimbersTitle => 'Ninguém ainda';

  @override
  String get adminNoClimbersMessage =>
      'Todos com perfil aparecem aqui, para bloquear ou desbloquear.';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get blocked => 'Bloqueado';

  @override
  String blockNameQuestion(String name) {
    return 'Bloquear $name?';
  }

  @override
  String get blockMessage =>
      'Não poderá usar o Grigri até você desbloquear, e os planos saem do Descobrir de todos.';

  @override
  String get blockedTitle => 'Sua conta está bloqueada';

  @override
  String get blockedMessage =>
      'Um administrador bloqueou sua conta, então por enquanto você não pode usar o Grigri.';

  @override
  String get yourPics => 'Suas fotos';

  @override
  String get grigriPics => 'GriGri Pics';

  @override
  String get yourPicsEmpty =>
      'Ainda não há fotos. Adicione uma, ou envie uma no chat.';

  @override
  String get grigriPicsEmpty => 'Ainda não há GriGri Pics deste lugar.';

  @override
  String get addPlanPic => 'Adicionar uma foto ao plano';

  @override
  String get deletePic => 'Apagar a foto';

  @override
  String get deletePicQuestion => 'Apagar esta foto?';

  @override
  String get deletePicMessage => 'Ela sai das fotos do plano para todos.';

  @override
  String get deleteChatPicMessage =>
      'Ela sai das fotos do plano; o chat a mantém.';

  @override
  String get delete => 'Apagar';

  @override
  String picCredit(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String picAddedBy(String name) {
    return 'Adicionada por $name';
  }

  @override
  String picFromChat(String name) {
    return 'Enviada no chat por $name';
  }

  @override
  String get premiumTitle => 'Grigri Premium';

  @override
  String get premiumPitch =>
      'Anuncie no Grigri: seus anúncios aparecem entre os planos em Buscar para todo mundo. O resto continua igual.';

  @override
  String premiumMonthly(String price) {
    return '$price por mês';
  }

  @override
  String premiumYearly(String price) {
    return '$price por ano';
  }

  @override
  String get premiumCheckoutHint =>
      'Você paga na página segura do Stripe, no navegador. Volte aqui quando terminar.';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium: renova em $date';
  }

  @override
  String premiumEndsOn(String date) {
    return 'Premium: termina em $date';
  }

  @override
  String get premiumManage => 'Gerenciar assinatura';

  @override
  String get premiumUnavailable => 'O Premium ainda não está disponível.';

  @override
  String get premiumCheckRefresh => 'Já paguei: verificar';

  @override
  String get errorOpenLink => 'Não foi possível abrir o link.';

  @override
  String get tabAds => 'Anúncios';

  @override
  String get adTag => 'Anúncio';

  @override
  String adBy(String name) {
    return 'Anúncio de $name';
  }

  @override
  String get swipeOpen => 'Abrir';

  @override
  String get swipeSkip => 'Pular';

  @override
  String get openAd => 'Abrir o link do anúncio';

  @override
  String get skipAd => 'Pular o anúncio';

  @override
  String get shareAd => 'Compartilhar o link do anúncio';

  @override
  String get adsTitle => 'Seus anúncios';

  @override
  String get adsEmptyTitle => 'Nenhum anúncio ainda';

  @override
  String get adsEmptyMessage =>
      'Adicione um anúncio: quando um admin aprovar, ele aparece entre os planos em Buscar para todo mundo.';

  @override
  String get newAd => 'Novo anúncio';

  @override
  String get adStatusPending => 'Aguardando revisão';

  @override
  String get adStatusApproved => 'Aprovado: em exibição';

  @override
  String get adStatusRejected => 'Recusado';

  @override
  String get deleteAdQuestion => 'Excluir este anúncio?';

  @override
  String get deleteAdMessage => 'Ele sai de Buscar para sempre.';

  @override
  String get adTextLabel => 'Texto sobre o anúncio';

  @override
  String get adLinkLabel => 'Link (https://…)';

  @override
  String get adLinkInvalid => 'Digite um endereço web começando com https://';

  @override
  String get adAddMedia => 'Adicionar foto ou vídeo';

  @override
  String get adRemoveMedia => 'Remover a foto ou o vídeo';

  @override
  String get adVideoPicked => 'Vídeo';

  @override
  String get adNeedsContent => 'Adicione texto, uma foto ou um vídeo.';

  @override
  String get adSubmit => 'Enviar para revisão';

  @override
  String get adSent => 'Enviado: um admin vai revisar.';

  @override
  String get adPreview => 'Prévia';

  @override
  String get adsNeedPremium =>
      'Seu Premium terminou: seus anúncios não aparecem. Renove no seu perfil.';

  @override
  String get adminUsersTab => 'Usuários';

  @override
  String get adminAdsTab => 'Anúncios';

  @override
  String get adminAdsTitle => 'Admin';

  @override
  String get adsOnDiscover => 'Em Buscar';

  @override
  String get adEveryOff => 'Sem anúncios';

  @override
  String adEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Um anúncio a cada $count planos',
      one: 'Um anúncio depois de cada plano',
    );
    return '$_temp0';
  }

  @override
  String get adApprove => 'Aprovar';

  @override
  String get adReject => 'Recusar';

  @override
  String get adminAdsEmpty => 'Nenhum anúncio aqui';

  @override
  String get routeFinder => 'Vias na rocha';

  @override
  String get routeFinderLoading => 'Preparando as paredes daqui…';

  @override
  String get routeFinderNoWalls =>
      'Ainda não há paredes conhecidas aqui. Registre a primeira via.';

  @override
  String routeFinderSeen(String wall, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vias',
      one: '1 via',
      zero: 'ainda sem vias',
    );
    return '$wall: $_temp0';
  }

  @override
  String get routeFinderPoint => 'Aponte a câmera para a parede';

  @override
  String get routeFinderSnap =>
      'Tire uma foto da parede para encontrar suas vias';

  @override
  String get cameraUnavailable => 'A câmera não está disponível.';

  @override
  String get recordRoute => 'Registrar uma via';

  @override
  String get teachView => 'Aprender esta vista';

  @override
  String get findRoutes => 'Encontrar vias';

  @override
  String get learnedView =>
      'Obrigado! O Grigri agora conhece melhor esta parede.';

  @override
  String get needTwoBolts => 'Toque pelo menos duas chapeletas.';

  @override
  String get routeSaved => 'Via salva.';

  @override
  String get undoBolt => 'Desfazer a última chapeleta';

  @override
  String get tapBolts => 'Toque cada chapeleta, do chão até a parada';

  @override
  String get tapBoltsNewWall =>
      'Rocha nova: toque cada chapeleta, a partir do chão. Esta foto vai ensinar a parede ao Grigri.';

  @override
  String get notRecognized => 'O Grigri não reconheceu esta parede.';

  @override
  String get saveRoute => 'Salvar a via';

  @override
  String get newWallNote =>
      'Uma parede nova: esta foto vai ensinar ao Grigri como ela é.';

  @override
  String get wallName => 'Parede';

  @override
  String get routeName => 'Nome da via';

  @override
  String get routeScale => 'Via';

  @override
  String get boulderScale => 'Boulder';

  @override
  String get routeGrade => 'Grau';

  @override
  String kmAway(String km) {
    return '$km km';
  }

  @override
  String get sectionWhoCanJoin => 'Quem pode entrar';

  @override
  String get planTypePrivate => 'Privado';

  @override
  String get planTypeOpen => 'Aberto';

  @override
  String get planTypeGuided => 'Guiado';

  @override
  String get planTypePrivateHint => 'Todo o grupo diz sim para cada novato.';

  @override
  String get planTypeOpenHint =>
      'Qualquer um pode entrar na hora, sem esperar um sim.';

  @override
  String get planTypeGuidedHint =>
      'Você guia e os escaladores pagam você. Só você responde aos pedidos.';

  @override
  String get pricePerClimber => 'Preço por escalador';

  @override
  String get priceInvalid =>
      'Informe um preço acima de 0, com no máximo duas casas decimais';

  @override
  String get currency => 'Moeda';

  @override
  String guidedPrice(String price) {
    return 'Guiado · $price';
  }

  @override
  String get paidToGuide => 'Pago ao guia, não pelo Grigri.';

  @override
  String get theGuideDecides => 'O guia decide';

  @override
  String get openJoinAtOnce => 'Aberto: entre na hora';

  @override
  String get signInBadge => '100% grátis';

  @override
  String get signInHeadline => 'Entre em um plano de escalada.';

  @override
  String get signInFreeLine => 'Grátis para todos: sem cartão, sem assinatura.';

  @override
  String get signInStampJoin => 'EU VOU';

  @override
  String get signInDeckWhen => 'Este sábado · Esportiva · 6b–7a';

  @override
  String get signInDeckWho => 'Mara, Jonas e mais 1';

  @override
  String get signInHowTitle => 'Como funciona';

  @override
  String get signInStep1Title => 'Crie um plano';

  @override
  String get signInStep1Body =>
      'Onde, quando e quais graus: um pico, um sábado, de 6a a 7a.';

  @override
  String get signInStep2Title => 'Deslize para a direita';

  @override
  String get signInStep2Body =>
      'Gostou de um plano? Deslize para a direita. O grupo aceita novatos um de cada vez, quando todos dizem sim.';

  @override
  String get signInStep3Title => 'Escalem juntos';

  @override
  String get signInStep3Body =>
      'Cada match abre o chat em grupo do plano: corda, carona e café.';

  @override
  String get signInFreeTitle => 'Grátis. De verdade.';

  @override
  String get signInFree1 => 'Planos e deslizar';

  @override
  String get signInFree2 => 'Matches e chats em grupo';

  @override
  String get signInFree3 => 'Fotos dos picos';

  @override
  String get signInFree4 => 'Sem cartão para se cadastrar';

  @override
  String get signInFreePremium =>
      'O Premium é opcional: serve só para anunciar no Grigri e para o localizador de vias. Escalar com o Grigri não custa nada.';

  @override
  String get signInFinalTitle =>
      'O plano de escalada deste fim de semana está a um deslize.';

  @override
  String get signInJoinFree => 'Entre grátis com o Google';

  @override
  String signInPhotoBy(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String get signInDeckWhen2 => 'Domingo · Via longa · 6a–6b';

  @override
  String get signInDeckWho2 => 'Iker e Lea';

  @override
  String get signInDeckWhen3 => 'No próximo fim de semana · Boulder · 6C–7A';

  @override
  String get signInDeckWho3 => 'Noor, Tomás e mais 2';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get support => 'Suporte';

  @override
  String get deleteAccount => 'Excluir conta';

  @override
  String get deleteAccountQuestion => 'Excluir sua conta?';

  @override
  String get deleteAccountMessage =>
      'Exclui sua conta do Grigri para sempre: seu perfil e suas fotos, suas mensagens e fotos nas conversas em grupo, seus pedidos e seus anúncios. Você sai de todos os seus planos: outra pessoa do plano assume os que você organiza, e um plano só com você termina. O Premium pago aqui com cartão é cancelado na hora, sem reembolso do tempo restante. Uma assinatura comprada pela Apple precisa ser cancelada nos Ajustes do iPhone. Você sai da conta em todos os dispositivos.';

  @override
  String get deleteAccountUnderstand =>
      'Entendo que isso não pode ser desfeito';

  @override
  String get deleteAccountConfirm => 'Excluir para sempre';

  @override
  String get errorDeleteAccount =>
      'Não foi possível excluir sua conta. Tente de novo.';

  @override
  String get moreActions => 'Mais';

  @override
  String get report => 'Denunciar';

  @override
  String blockPerson(String name) {
    return 'Bloquear $name';
  }

  @override
  String get reportTitle => 'Por que você está denunciando isto?';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Assédio';

  @override
  String get reportReasonInappropriate => 'Conteúdo impróprio';

  @override
  String get reportReasonFake => 'Perfil falso';

  @override
  String get reportReasonOther => 'Outro motivo';

  @override
  String get reportDetailsHint => 'Algo mais que devemos saber? (opcional)';

  @override
  String get reportSend => 'Enviar denúncia';

  @override
  String get reportThanks => 'Obrigado, vamos analisar em até 24 horas.';

  @override
  String get blockPersonMessage =>
      'Vocês não verão os planos um do outro, nenhum poderá pedir para entrar num plano em que o outro esteja, os pedidos dessa pessoa aos seus planos são recusados e você não verá as mensagens dela. Ela não é avisada.';

  @override
  String blockedPersonDone(String name) {
    return '$name foi bloqueado.';
  }

  @override
  String get blockedPeopleTitle => 'Pessoas bloqueadas';

  @override
  String get blockedPeopleEmpty => 'Você não bloqueou ninguém.';

  @override
  String get adminReportsTab => 'Denúncias';

  @override
  String get adminReportsEmpty => 'Nenhuma denúncia para analisar.';

  @override
  String reportedBy(String name) {
    return 'Denunciado por $name';
  }

  @override
  String get reportKindProfile => 'Perfil';

  @override
  String get reportKindPlan => 'Plano';

  @override
  String get reportKindMessage => 'Mensagem do chat';

  @override
  String get reportKindPic => 'Foto do plano';

  @override
  String get reportKindAd => 'Anúncio';

  @override
  String get reportDismiss => 'Descartar';

  @override
  String get reportRemove => 'Remover conteúdo';

  @override
  String get reportBlock => 'Bloquear escalador';

  @override
  String get noticeReportsTitle => 'Novas denúncias para analisar';

  @override
  String get noticeReportsBody =>
      'Admin → Denúncias · responda em até 24 horas';

  @override
  String get errorObjectionable =>
      'Mantenha a gentileza: o texto tem palavras que o Grigri não permite.';
}
