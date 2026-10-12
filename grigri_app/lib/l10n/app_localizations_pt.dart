// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get disciplineSport => 'Desportiva';

  @override
  String get disciplineTrad => 'Tradicional';

  @override
  String get disciplineBouldering => 'Boulder';

  @override
  String get disciplineGym => 'Ginásio';

  @override
  String get gradeSystemEuropean => 'Europeu';

  @override
  String get gradeSystemAmerican => 'Americano';

  @override
  String get gearRope => 'Corda';

  @override
  String get gearQuickdraws => 'Expressos';

  @override
  String get gearRack => 'Proteções móveis';

  @override
  String get gearCrashPad => 'Crash pad';

  @override
  String get gearCar => 'Carro';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get more => 'Mais';

  @override
  String get refresh => 'Atualizar';

  @override
  String get signOut => 'Terminar sessão';

  @override
  String get tryAgain => 'Tentar de novo';

  @override
  String get retry => 'Repetir';

  @override
  String get newPlan => 'Novo plano';

  @override
  String get you => 'Tu';

  @override
  String get youLower => 'tu';

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
    return '$yes de $total disseram que sim';
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
  String get errorGeneric => 'Algo correu mal.';

  @override
  String errorStatus(int status) {
    return 'Algo correu mal ($status).';
  }

  @override
  String get errorTimeout => 'O servidor demorou demasiado a responder.';

  @override
  String get errorUnreachable => 'Não foi possível contactar o servidor.';

  @override
  String get errorPhotoTimeout => 'O carregamento da foto demorou demasiado.';

  @override
  String get errorPhotoUnreachable => 'Não foi possível carregar a foto.';

  @override
  String errorPhotoStatus(int status) {
    return 'O carregamento da foto falhou ($status).';
  }

  @override
  String get errorPhotoType => 'Usa uma foto JPEG, PNG ou WebP.';

  @override
  String get errorSignedOut => 'Sessão terminada: inicia sessão de novo.';

  @override
  String get errorSignIn =>
      'Não foi possível iniciar sessão com o Google. Tenta de novo.';

  @override
  String get errorSession => 'Não foi possível iniciar sessão. Tenta de novo.';

  @override
  String get errorSignOutEverywhere =>
      'Não foi possível terminar sessão em todo o lado. Tenta de novo.';

  @override
  String get loadFailedTitle => 'Não foi possível carregar o teu perfil';

  @override
  String get signInTagline =>
      'Encontra parceiros de escalada: cria um plano ou desliza para a direita num deles, e escalem juntos.';

  @override
  String get signInWithGoogle => 'Iniciar sessão com o Google';

  @override
  String get devSignInHeading => 'Acesso de desenvolvimento · só API local';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get devSignIn => 'Acesso de desenvolvimento';

  @override
  String get signInUnconfigured =>
      'O início de sessão não está configurado nesta versão (sem ID de cliente Google).';

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
  String get yourGrades => 'O teu grau';

  @override
  String get profileClimbs => 'Escala';

  @override
  String get profileGear => 'Material';

  @override
  String gearPhotoOf(String name, int number) {
    return 'Material de $name, foto $number';
  }

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Idioma do sistema';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get signOutQuestion => 'Terminar sessão?';

  @override
  String get signOutMessage =>
      'O teu perfil, planos e conversas ficam guardados; inicia sessão de novo para os veres.';

  @override
  String get signOutEverywhere => 'Terminar sessão em todo o lado';

  @override
  String get signOutEverywhereQuestion => 'Terminar sessão em todo o lado?';

  @override
  String get signOutEverywhereMessage =>
      'Termina a tua sessão em todos os telemóveis e navegadores onde a iniciaste, incluindo este. O teu perfil, planos e conversas ficam guardados.';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get profileFootnote =>
      'O teu perfil é sobre ti: o que escalas e o material que tens. O quando e o onde são para os planos, criados à parte em Planos.';

  @override
  String get takePhoto => 'Tirar uma foto';

  @override
  String get choosePhoto => 'Escolher uma foto';

  @override
  String get removePhoto => 'Remover a foto';

  @override
  String get photoFailed => 'Não foi possível obter essa foto';

  @override
  String get addPhoto => 'Adicionar uma foto';

  @override
  String get changePhoto => 'Mudar a tua foto';

  @override
  String get nameLabel => 'Nome';

  @override
  String get nameRequired => 'O teu nome, por favor';

  @override
  String get ageLabel => 'Idade (opcional)';

  @override
  String ageRange(int min, int max) {
    return 'De $min a $max';
  }

  @override
  String get bioLabel => 'Sobre ti';

  @override
  String get whatYouClimb => 'O que escalas';

  @override
  String get whatYouClimbHint =>
      'Escolhe as tuas disciplinas e os graus que escalas.';

  @override
  String get gearYouCanBring => 'Material que podes levar';

  @override
  String get gearHint => 'Adiciona também fotos.';

  @override
  String gearPhoto(int number) {
    return 'Foto do material $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Remover a foto do material $number';
  }

  @override
  String get addGearPhoto => 'Adicionar uma foto do material';

  @override
  String get whereYouClimb => 'Onde escalas';

  @override
  String get whereYouClimbHint =>
      'Os planos perto daqui aparecem primeiro em Descobrir. Só tu vês isto.';

  @override
  String get setYourLocation => 'Define a tua localização';

  @override
  String get yourLocation => 'A tua localização';

  @override
  String get clearYourLocation => 'Apagar a tua localização';

  @override
  String removeArea(String name) {
    return 'Remover $name';
  }

  @override
  String get addArea => 'Adicionar uma zona';

  @override
  String get locationSearchLabel => 'Uma escola ou ginásio perto dali';

  @override
  String get search => 'Pesquisar';

  @override
  String get locationPrivacy =>
      'Guardada com cerca de 1 km de precisão, e só tu a vês.';

  @override
  String placesAttribution(String attribution) {
    return 'Locais: $attribution';
  }

  @override
  String get loadingPlaces => 'A carregar locais…';

  @override
  String get noPlacesFound => 'Nenhum local encontrado';

  @override
  String distanceKm(int km) {
    String _temp0 = intl.Intl.pluralLogic(
      km,
      locale: localeName,
      other: 'A $km km de ti',
      zero: 'A menos de 1 km de ti',
    );
    return '$_temp0';
  }

  @override
  String get setWhereYouClimbHint =>
      'Define onde escalas para veres primeiro os planos perto de ti.';

  @override
  String get setAction => 'Definir';

  @override
  String get discoverTitle => 'Descobrir planos';

  @override
  String askedToJoinPending(String organizer) {
    return 'Pedido enviado: pendente. $organizer vai decidir; vais receber uma notificação.';
  }

  @override
  String askedToJoinPendingGroup(String organizer) {
    return 'Pedido enviado: pendente. $organizer e o grupo vão decidir; vais receber uma notificação.';
  }

  @override
  String get noPlansToJoinTitle => 'Sem planos para te juntares agora';

  @override
  String get noPlansToJoinMessage =>
      'Ainda ninguém tem um plano aberto para ti. Cria o teu: os escaladores compatíveis vão pedir para se juntar.';

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
  String get noChatsTitle => 'Ainda sem conversas';

  @override
  String get noChatsMessage =>
      'Cada plano em que estás tem uma conversa de grupo. Cria um plano, ou pede para te juntares a um, e a conversa aparece aqui.';

  @override
  String get findPlan => 'Encontrar um plano';

  @override
  String messagePreview(String author, String text) {
    return '$author: $text';
  }

  @override
  String toAnswer(int count) {
    return '$count por responder';
  }

  @override
  String get notInGroupTitle => 'Não estás neste grupo';

  @override
  String get notInGroupMessage =>
      'Saíste deste plano, por isso a conversa está fechada.';

  @override
  String get messageHint => 'Escreve ao grupo';

  @override
  String get send => 'Enviar';

  @override
  String get wantsToJoinYourAnswer => 'Quer entrar · a tua resposta';

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
      'sport': 'Ainda sem grau em desportiva',
      'trad': 'Ainda sem grau em tradicional',
      'bouldering': 'Ainda sem grau em boulder',
      'gym': 'Ainda sem grau em ginásio',
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
      other: 'Disseram que sim: $names',
      one: 'Disse que sim: $names',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'falta $names';
  }

  @override
  String get itsAMatch => 'Temos match!';

  @override
  String get matchEveryoneSaidYes =>
      'Todo o grupo disse que sim. Vão escalar juntos:';

  @override
  String matchJoinsGroup(String name) {
    return '$name junta-se ao grupo:';
  }

  @override
  String get openGroupChat => 'Abrir a conversa do grupo';

  @override
  String get keepSwiping => 'Continuar a deslizar';

  @override
  String get notificationsTitle => 'Notificações';

  @override
  String get nothingYetTitle => 'Ainda nada';

  @override
  String get nothingYetMessage =>
      'Quando alguém pedir para entrar num plano em que estás, ou um grupo responder ao teu pedido, vais saber aqui.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name quer entrar';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · responde na conversa do grupo';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'Estás dentro: $plan';
  }

  @override
  String get noticeAcceptedBody => 'O grupo aceitou-te. Diz olá na conversa.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Desta vez não: $plan';
  }

  @override
  String get noticeDeclinedBody => 'O grupo recusou o teu pedido.';

  @override
  String get newTag => 'Novo';

  @override
  String get planGoneTitle => 'O plano já não existe';

  @override
  String get planGoneMessage =>
      'Todos saíram deste plano, ou já não está aberto.';

  @override
  String get yourPlan => 'O teu plano';

  @override
  String get planTitle => 'Plano';

  @override
  String get edit => 'Editar';

  @override
  String get declinedGroupSaidNo => 'Recusado: o grupo disse que não';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'Pendente: $yes de $total disseram que sim';
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
  String get youSaidYes => 'Disseste que sim';

  @override
  String get answerInChat => 'Responde na conversa';

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
  String get cancelPlanMessage => 'O plano e a conversa vão desaparecer.';

  @override
  String leaveOrganizerMessage(String name) {
    return '$name vai organizá-lo.';
  }

  @override
  String get leaveMessage => 'Não vais poder voltar a entrar.';

  @override
  String get stay => 'Ficar';

  @override
  String get leave => 'Sair';

  @override
  String get editPlan => 'Editar plano';

  @override
  String get pickFutureTime => 'Escolhe uma hora que ainda não passou.';

  @override
  String get sectorLabel => 'Setor, escola ou ginásio';

  @override
  String get sectorHint => 'Pesquisa ou escreve';

  @override
  String sectorsAttribution(String attribution) {
    return 'Setores: $attribution';
  }

  @override
  String get whereRequired => 'Onde vais escalar?';

  @override
  String get sectionDiscipline => 'Escalada';

  @override
  String get sectionWhere => 'Onde';

  @override
  String get sectionWhen => 'Quando';

  @override
  String get sectionGrades => 'Graus';

  @override
  String get sectionNotes => 'Notas';

  @override
  String get notesHint =>
      'Ponto de encontro, lugares no carro, as vias que tens em mente…';

  @override
  String get publishPlan => 'Publicar o plano';

  @override
  String get yourPlans => 'Os teus planos';

  @override
  String get noPlansYetTitle => 'Ainda sem planos';

  @override
  String get noPlansYetMessage =>
      'Cria um plano (o quê, onde, quando) e os escaladores compatíveis vão pedir para entrar. Ou desliza para a direita num deles em Descobrir.';

  @override
  String get plansClimbing => 'A escalar';

  @override
  String get plansAskedToJoin => 'Pedidos';

  @override
  String get organizing => 'Organizas tu';

  @override
  String get accepted => 'Aceite';

  @override
  String toReview(int count) {
    return '$count por rever';
  }

  @override
  String get groupSaidNo => 'O grupo disse que não';

  @override
  String waitingForNames(String names) {
    return 'À espera de $names';
  }

  @override
  String get dismiss => 'Descartar';

  @override
  String get adminTitle => 'Admin: pedidos';

  @override
  String get noOpenRequestsTitle => 'Sem pedidos em aberto';

  @override
  String get noOpenRequestsMessage =>
      'Quando alguém pede para entrar num plano, o pedido aparece aqui para o aprovares ou rejeitares.';

  @override
  String get aPlan => 'um plano';

  @override
  String askedAt(String day, String time) {
    return 'Pedido a $day, $time';
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
    return 'Entra em $plan agora, como se todo o grupo tivesse dito que sim.';
  }

  @override
  String adminJoined(String name, String plan) {
    return '$name entrou em $plan.';
  }

  @override
  String get roles => 'Funções';

  @override
  String get rolesSignedOut =>
      'Sessão não iniciada: as tuas funções aparecem aqui quando iniciares sessão.';

  @override
  String get rolesFailed => 'Não foi possível obter as tuas funções do rbacr.';

  @override
  String get noRoles => 'Ainda sem funções no Grigri.';

  @override
  String rolesAs(String email) {
    return 'Como $email';
  }
}
