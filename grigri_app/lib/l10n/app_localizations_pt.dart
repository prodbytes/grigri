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
  String get errorSession => 'Não foi possível entrar. Tente de novo.';

  @override
  String get errorSignOutEverywhere =>
      'Não foi possível sair de todos os dispositivos. Tente de novo.';

  @override
  String get loadFailedTitle => 'Não foi possível carregar seu perfil';

  @override
  String get signInTagline =>
      'Encontre parceiros de escalada: crie um plano ou deslize para a direita em um, e escalem juntos.';

  @override
  String get signInWithGoogle => 'Entrar com o Google';

  @override
  String get devSignInHeading => 'Acesso de desenvolvimento · só API local';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get devSignIn => 'Acesso de desenvolvimento';

  @override
  String get signInUnconfigured =>
      'O login não está configurado nesta versão (sem ID de cliente do Google).';

  @override
  String get tabDiscover => 'Descobrir';

  @override
  String get tabPlans => 'Planos';

  @override
  String get tabChats => 'Conversas';

  @override
  String get tabNotifications => 'Notificações';

  @override
  String get tabProfile => 'Perfil';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'O plano';

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
  String get createProfile => 'Crie seu perfil';

  @override
  String get takePhoto => 'Tirar uma foto';

  @override
  String get choosePhoto => 'Escolher uma foto';

  @override
  String get removePhoto => 'Remover a foto';

  @override
  String get photoFailed => 'Não foi possível pegar essa foto';

  @override
  String get welcomeIntro =>
      'Boas-vindas ao Grigri! Conte aos escaladores quem você é e o que escala: eles veem isso quando você pede para entrar nos planos deles.';

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
  String get startClimbing => 'Começar a escalar';

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
  String distanceKm(int km) {
    String _temp0 = intl.Intl.pluralLogic(
      km,
      locale: localeName,
      other: 'A $km km de você',
      zero: 'A menos de 1 km de você',
    );
    return '$_temp0';
  }

  @override
  String get setWhereYouClimbHint =>
      'Defina onde você escala para ver primeiro os planos perto de você.';

  @override
  String get setAction => 'Definir';

  @override
  String get discoverTitle => 'Descobrir planos';

  @override
  String askedToJoinPending(String organizer) {
    return 'Pedido enviado: pendente. $organizer vai decidir; você vai receber uma notificação.';
  }

  @override
  String askedToJoinPendingGroup(String organizer) {
    return 'Pedido enviado: pendente. $organizer e o grupo vão decidir; você vai receber uma notificação.';
  }

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
  String get organizedBy => 'Organizado por';

  @override
  String get alsoInGroup => 'Também no grupo';

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
  String get notificationsTitle => 'Notificações';

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
  String get leavePlan => 'Sair do plano';

  @override
  String get cancelPlanQuestion => 'Cancelar o plano?';

  @override
  String get leavePlanQuestion => 'Sair do plano?';

  @override
  String get cancelPlanMessage => 'O plano e a conversa vão sumir.';

  @override
  String leaveOrganizerMessage(String name) {
    return '$name vai organizar.';
  }

  @override
  String get leaveMessage => 'Você não vai poder entrar de novo.';

  @override
  String get stay => 'Ficar';

  @override
  String get leave => 'Sair';

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
  String get adminTitle => 'Admin: pedidos';

  @override
  String get noOpenRequestsTitle => 'Nenhum pedido em aberto';

  @override
  String get noOpenRequestsMessage =>
      'Quando alguém pede para entrar em um plano, o pedido aparece aqui para você aprovar ou rejeitar.';

  @override
  String get aPlan => 'um plano';

  @override
  String askedAt(String day, String time) {
    return 'Pediu em $day, $time';
  }

  @override
  String get reject => 'Rejeitar';

  @override
  String get approve => 'Aprovar';

  @override
  String rejectNameQuestion(String name) {
    return 'Rejeitar $name?';
  }

  @override
  String rejectMessage(String plan) {
    return 'Não vai entrar em $plan, e vai saber que o grupo recusou.';
  }

  @override
  String approveNameQuestion(String name) {
    return 'Aprovar $name?';
  }

  @override
  String approveMessage(String plan) {
    return 'Entra em $plan agora, como se o grupo todo tivesse dito sim.';
  }

  @override
  String adminJoined(String name, String plan) {
    return '$name entrou em $plan.';
  }

  @override
  String get roles => 'Funções';

  @override
  String get rolesSignedOut =>
      'Você não entrou: suas funções aparecem aqui quando você entrar.';

  @override
  String get rolesFailed => 'Não foi possível buscar suas funções no rbacr.';

  @override
  String get noRoles => 'Nenhuma função no Grigri ainda.';

  @override
  String rolesAs(String email) {
    return 'Como $email';
  }
}
