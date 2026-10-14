// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get disciplineSport => 'Esportiva';

  @override
  String get disciplineTrad => 'Clàssica';

  @override
  String get disciplineBouldering => 'Bloc';

  @override
  String get disciplineGym => 'Rocòdrom';

  @override
  String get gradeSystemEuropean => 'Europeu';

  @override
  String get gradeSystemAmerican => 'Americà';

  @override
  String get gearRope => 'Corda';

  @override
  String get gearQuickdraws => 'Cintes exprés';

  @override
  String get gearRack => 'Material d\'autoprotecció';

  @override
  String get gearCrashPad => 'Crash pad';

  @override
  String get gearCar => 'Cotxe';

  @override
  String get save => 'Desa';

  @override
  String get cancel => 'Cancel·la';

  @override
  String get more => 'Més';

  @override
  String get refresh => 'Actualitza';

  @override
  String get signOut => 'Tanca la sessió';

  @override
  String get tryAgain => 'Torna-ho a provar';

  @override
  String get retry => 'Reintenta';

  @override
  String get newPlan => 'Nou pla';

  @override
  String get you => 'Tu';

  @override
  String get youLower => 'tu';

  @override
  String get someone => 'Algú';

  @override
  String climberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count escaladors',
      one: '1 escalador',
    );
    return '$_temp0';
  }

  @override
  String saidYesCount(int yes, int total) {
    return '$yes de $total han dit que sí';
  }

  @override
  String get declined => 'Rebutjada';

  @override
  String get pending => 'Pendent';

  @override
  String get accept => 'Accepta';

  @override
  String get decline => 'Rebutja';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get errorGeneric => 'Alguna cosa ha fallat.';

  @override
  String errorStatus(int status) {
    return 'Alguna cosa ha fallat ($status).';
  }

  @override
  String get errorTimeout => 'El servidor ha trigat massa a respondre.';

  @override
  String get errorUnreachable => 'No s\'ha pogut connectar amb el servidor.';

  @override
  String get errorPhotoTimeout => 'La pujada de la foto ha trigat massa.';

  @override
  String get errorPhotoUnreachable => 'No s\'ha pogut pujar la foto.';

  @override
  String errorPhotoStatus(int status) {
    return 'La pujada de la foto ha fallat ($status).';
  }

  @override
  String get errorPhotoType => 'Fes servir una foto JPEG, PNG o WebP.';

  @override
  String get errorSignedOut => 'Sessió tancada: torna a iniciar la sessió.';

  @override
  String get errorSignIn =>
      'No s\'ha pogut iniciar la sessió amb Google. Torna-ho a provar.';

  @override
  String get errorSession =>
      'No s\'ha pogut iniciar la sessió. Torna-ho a provar.';

  @override
  String get errorSignOutEverywhere =>
      'No s\'ha pogut tancar la sessió a tot arreu. Torna-ho a provar.';

  @override
  String get loadFailedTitle => 'No s\'ha pogut carregar el teu perfil';

  @override
  String get signInTagline =>
      'Troba companys d\'escalada: fes un pla o llisca a la dreta en un, i escaleu junts.';

  @override
  String get signInWithGoogle => 'Inicia la sessió amb Google';

  @override
  String get tabDiscover => 'Cerca';

  @override
  String get tabPlans => 'Plans';

  @override
  String get tabChats => 'Xats';

  @override
  String get tabNotifications => 'Avisos';

  @override
  String get tabProfile => 'Jo';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'El pla';

  @override
  String get demoTag => 'Demo';

  @override
  String get demoNotice =>
      'Demo: no són dades reals, només una demostració perquè vegis com funciona Grigri.';

  @override
  String get yourGrades => 'El teu grau';

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
  String get languageSystem => 'Idioma del sistema';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get signOutQuestion => 'Vols tancar la sessió?';

  @override
  String get signOutMessage =>
      'El teu perfil, els plans i els xats es queden desats; torna a iniciar la sessió per veure-ls.';

  @override
  String get signOutEverywhere => 'Tanca la sessió a tot arreu';

  @override
  String get signOutEverywhereQuestion => 'Vols tancar la sessió a tot arreu?';

  @override
  String get signOutEverywhereMessage =>
      'Tanca la teva sessió a tots els mòbils i navegadors on l\'has iniciada, també en aquest. El teu perfil, els plans i els xats es queden desats.';

  @override
  String get editProfile => 'Edita el perfil';

  @override
  String get profileFootnote =>
      'El teu perfil parla de tu: què escales i quin material tens. El quan i l\'on són per als plans, que es fan a part a Plans.';

  @override
  String get takePhoto => 'Fes una foto';

  @override
  String get choosePhoto => 'Tria una foto';

  @override
  String get removePhoto => 'Treu la foto';

  @override
  String get photoFailed => 'No s\'ha pogut obtenir la foto';

  @override
  String get addPhoto => 'Afegeix una foto';

  @override
  String get changePhoto => 'Canvia la foto';

  @override
  String get nameLabel => 'Nom';

  @override
  String get nameRequired => 'El teu nom, si us plau';

  @override
  String get ageLabel => 'Edat (opcional)';

  @override
  String ageRange(int min, int max) {
    return 'De $min a $max';
  }

  @override
  String get bioLabel => 'Sobre tu';

  @override
  String get whatYouClimb => 'Què escales';

  @override
  String get whatYouClimbHint =>
      'Tria les teves disciplines i els graus que escales.';

  @override
  String get gearYouCanBring => 'Material que pots portar';

  @override
  String get gearHint => 'Afegeix-hi fotos, també.';

  @override
  String gearPhoto(int number) {
    return 'Foto del material $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Treu la foto del material $number';
  }

  @override
  String get addGearPhoto => 'Afegeix una foto del material';

  @override
  String get whereYouClimb => 'On escales';

  @override
  String get whereYouClimbHint =>
      'Els plans propers surten primer a Descobreix. Només ho veus tu.';

  @override
  String get setYourLocation => 'Indica la teva ubicació';

  @override
  String get yourLocation => 'La teva ubicació';

  @override
  String get clearYourLocation => 'Esborra la teva ubicació';

  @override
  String removeArea(String name) {
    return 'Treu $name';
  }

  @override
  String get addArea => 'Afegeix una zona';

  @override
  String get locationSearchLabel => 'Una escola o rocòdrom a prop d\'allà';

  @override
  String get search => 'Cerca';

  @override
  String get locationPrivacy =>
      'Es desa amb una precisió d\'1 km i només la veus tu.';

  @override
  String placesAttribution(String attribution) {
    return 'Llocs: $attribution';
  }

  @override
  String get loadingPlaces => 'Carregant llocs…';

  @override
  String get noPlacesFound => 'No s\'ha trobat cap lloc';

  @override
  String get useCurrentLocation => 'Fes servir la meva ubicació actual';

  @override
  String get locationNotFound => 'No s\'ha pogut saber on ets. Cerca un lloc.';

  @override
  String nearPlace(String place) {
    return 'A prop de $place';
  }

  @override
  String get currentLocation => 'On soc';

  @override
  String get setWhereYouClimbHint =>
      'Indica on escales per veure primer els plans propers.';

  @override
  String get setAction => 'Indica';

  @override
  String get discoverTitle => 'Descobreix plans';

  @override
  String get askedToJoinSent =>
      'Sol·licitud enviada. Rebràs un avís quan t\'acceptin.';

  @override
  String get noPlansToJoinTitle => 'Ara mateix no hi ha plans';

  @override
  String get noPlansToJoinMessage =>
      'Encara ningú no té cap pla obert per a tu. Fes-ne un: els escaladors que hi encaixin demanaran unir-se.';

  @override
  String get swipeJoin => 'M\'hi uneixo';

  @override
  String get swipePass => 'Passo';

  @override
  String get pass => 'Passa';

  @override
  String get askToJoin => 'Demana unir-te';

  @override
  String get sharePlan => 'Comparteix aquest pla';

  @override
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  ) {
    return 'Pla d\'escalada a Grigri: $discipline a $place, $when. $link';
  }

  @override
  String get organizedBy => 'Organitza';

  @override
  String get alsoInGroup => 'També al grup';

  @override
  String get showGroup => 'Mostra el grup';

  @override
  String get hideGroup => 'Amaga el grup';

  @override
  String get chatsTitle => 'Xats';

  @override
  String get noChatsTitle => 'Encara no hi ha xats';

  @override
  String get noChatsMessage =>
      'Cada pla on ets té un xat de grup. Fes un pla, o demana unir-te a un, i el seu xat apareixerà aquí.';

  @override
  String get findPlan => 'Troba un pla';

  @override
  String messagePreview(String author, String text) {
    return '$author: $text';
  }

  @override
  String toAnswer(int count) {
    return '$count per respondre';
  }

  @override
  String get notInGroupTitle => 'No ets en aquest grup';

  @override
  String get notInGroupMessage =>
      'Has deixat aquest pla, així que el seu xat està tancat.';

  @override
  String get messageHint => 'Escriu al grup';

  @override
  String get send => 'Envia';

  @override
  String get wantsToJoinYourAnswer => 'S\'hi vol unir · la teva resposta';

  @override
  String declineName(String name) {
    return 'Rebutja $name';
  }

  @override
  String acceptName(String name) {
    return 'Accepta $name';
  }

  @override
  String askedToJoinAt(String time) {
    return 'Ha demanat unir-se · $time';
  }

  @override
  String noGradesYet(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Encara sense grau en esportiva',
      'trad': 'Encara sense grau en clàssica',
      'bouldering': 'Encara sense grau en bloc',
      'gym': 'Encara sense grau en rocòdrom',
      'other': 'Encara sense grau',
    });
    return '$_temp0';
  }

  @override
  String get joined => 'S\'hi ha unit';

  @override
  String get closed => 'Tancada';

  @override
  String namesSaidYes(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Han dit que sí: $names',
      one: 'Ha dit que sí: $names',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'falta $names';
  }

  @override
  String get itsAMatch => 'Hi ha match!';

  @override
  String get matchEveryoneSaidYes =>
      'Tot el grup ha dit que sí. Escaleu junts:';

  @override
  String matchJoinsGroup(String name) {
    return '$name s\'uneix al grup:';
  }

  @override
  String get openGroupChat => 'Obre el xat del grup';

  @override
  String get keepSwiping => 'Continua lliscant';

  @override
  String get notificationsTitle => 'Avisos';

  @override
  String get nothingYetTitle => 'Res encara';

  @override
  String get nothingYetMessage =>
      'Quan algú demani unir-se a un pla on ets, o un grup respongui la teva sol·licitud, t\'assabentaràs aquí.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name s\'hi vol unir';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · respon al xat del grup';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'Ja hi ets: $plan';
  }

  @override
  String get noticeAcceptedBody => 'El grup t\'ha acceptat. Saluda al xat.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Aquesta vegada no: $plan';
  }

  @override
  String get noticeDeclinedBody => 'El grup ha rebutjat la teva sol·licitud.';

  @override
  String get newTag => 'Nou';

  @override
  String get planGoneTitle => 'El pla ja no existeix';

  @override
  String get planGoneMessage =>
      'Tothom ha deixat aquest pla, o ja no està obert.';

  @override
  String get yourPlan => 'El teu pla';

  @override
  String get planTitle => 'Pla';

  @override
  String get edit => 'Edita';

  @override
  String get declinedGroupSaidNo => 'Rebutjada: el grup ha dit que no';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'Pendent: $yes de $total han dit que sí';
  }

  @override
  String theGroupCount(int count) {
    return 'El grup · $count';
  }

  @override
  String get organizer => 'Organitzador';

  @override
  String get member => 'Membre';

  @override
  String get askingToJoin => 'S\'hi volen unir';

  @override
  String get youSaidYes => 'Has dit que sí';

  @override
  String get answerInChat => 'Respon al xat';

  @override
  String get groupChat => 'Xat del grup';

  @override
  String get cancelPlan => 'Cancel·la el pla';

  @override
  String get cancelPlanQuestion => 'Vols cancel·lar el pla?';

  @override
  String get cancelPlanMessage => 'El pla i el seu xat desapareixeran.';

  @override
  String get cancelPlanOthersMessage =>
      'Sortirà dels teus plans i xats; els altres el mantenen. No t\'hi podràs tornar a unir.';

  @override
  String get cancelPlanOrganizerMessage =>
      'Sortirà dels teus plans i xats; els altres el mantenen i un d\'ells, triat a l\'atzar, l\'organitzarà. No t\'hi podràs tornar a unir.';

  @override
  String get keepPlan => 'Mantén-lo';

  @override
  String get confirmCancelPlan => 'Cancel·la\'l';

  @override
  String get editPlan => 'Edita el pla';

  @override
  String get pickFutureTime => 'Tria una hora que encara no hagi passat.';

  @override
  String get sectorLabel => 'Sector, escola o rocòdrom';

  @override
  String get sectorHint => 'Cerca o escriu-lo';

  @override
  String sectorsAttribution(String attribution) {
    return 'Sectors: $attribution';
  }

  @override
  String get whereRequired => 'On escalaràs?';

  @override
  String get sectionDiscipline => 'Escalada';

  @override
  String get sectionWhere => 'On';

  @override
  String get sectionWhen => 'Quan';

  @override
  String get sectionGrades => 'Graus';

  @override
  String get sectionNotes => 'Notes';

  @override
  String get notesHint =>
      'Punt de trobada, places al cotxe, les vies que tens al cap…';

  @override
  String get publishPlan => 'Publica el pla';

  @override
  String get yourPlans => 'Els teus plans';

  @override
  String get noPlansYetTitle => 'Encara no hi ha plans';

  @override
  String get noPlansYetMessage =>
      'Fes un pla (què, on, quan) i els escaladors que hi encaixin demanaran unir-se. O llisca a la dreta en un a Descobreix.';

  @override
  String get plansClimbing => 'Hi vaig';

  @override
  String get plansAskedToJoin => 'Sol·licitats';

  @override
  String get organizing => 'Organitzes tu';

  @override
  String get accepted => 'Acceptat';

  @override
  String toReview(int count) {
    return '$count per revisar';
  }

  @override
  String get groupSaidNo => 'El grup ha dit que no';

  @override
  String waitingForNames(String names) {
    return 'Falta: $names';
  }

  @override
  String get dismiss => 'Descarta';

  @override
  String get adminTitle => 'Admin: sol·licituds';

  @override
  String get noOpenRequestsTitle => 'No hi ha sol·licituds obertes';

  @override
  String get noOpenRequestsMessage =>
      'Quan algú demana unir-se a un pla, la seva sol·licitud apareix aquí perquè l\'aprovis o la rebutgis.';

  @override
  String get aPlan => 'un pla';

  @override
  String askedAt(String day, String time) {
    return 'Demanat el $day, $time';
  }

  @override
  String get reject => 'Rebutja';

  @override
  String get approve => 'Aprova';

  @override
  String rejectNameQuestion(String name) {
    return 'Vols rebutjar $name?';
  }

  @override
  String rejectMessage(String plan) {
    return 'No s\'unirà a $plan i se li dirà que el grup ho ha rebutjat.';
  }

  @override
  String approveNameQuestion(String name) {
    return 'Vols aprovar $name?';
  }

  @override
  String approveMessage(String plan) {
    return 'S\'uneix a $plan ara, com si tot el grup hagués dit que sí.';
  }

  @override
  String adminJoined(String name, String plan) {
    return '$name s\'ha unit a $plan.';
  }

  @override
  String get roles => 'Rols';

  @override
  String get rolesFailed => 'No s\'han pogut obtenir els teus rols de rbacr.';

  @override
  String get noRoles => 'Encara no tens rols a Grigri.';
}
