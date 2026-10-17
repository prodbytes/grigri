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
  String get gearBelayDevice => 'Assegurador';

  @override
  String get gearHarness => 'Arnès';

  @override
  String get gearHelmet => 'Casc';

  @override
  String get gearShoes => 'Peus de gat';

  @override
  String get yourGear => 'El teu material';

  @override
  String get editGear => 'Edita el material';

  @override
  String get addGear => 'Afegeix el teu material';

  @override
  String get gearEmpty =>
      'Afegeix el material que tens, amb fotos: els grups dels teus plans el veuen i comproven que tenen el que cal.';

  @override
  String get gearShared => 'Per al grup';

  @override
  String get gearSharedHint =>
      'El grup el comparteix: una corda serveix per a dos.';

  @override
  String get gearPersonal => 'El teu';

  @override
  String get gearPersonalHint => 'Cada persona necessita el seu.';

  @override
  String get gearPhotos => 'Fotos';

  @override
  String get planGearAllSet => 'El grup té tot el que necessita.';

  @override
  String planGearMissing(String items) {
    return 'Falta material: $items';
  }

  @override
  String get planGearGym =>
      'El rocòdrom té cordes i matalassos, i lloga la resta.';

  @override
  String get planGearGuided =>
      'El guia porta el material del grup: comprova que tens el teu.';

  @override
  String get noGearListed => 'Sense material';

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
  String get errorSignInApple =>
      'No s\'ha pogut iniciar la sessió amb Apple. Torna-ho a provar.';

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
      'Fes un pla o llisca a la dreta en un, i escaleu junts.';

  @override
  String get signInWithGoogle => 'Inicia la sessió amb Google';

  @override
  String get signInWithApple => 'Inicia la sessió amb Apple';

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
  String get demoNotice => 'Demo: persones i plans inventats.';

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
  String get gradeSystem => 'Sistema de graus';

  @override
  String get gradeSystemHint =>
      'Com s\'escriuen els graus a l\'app, aquí per a una via i un bloc.';

  @override
  String get whatYouClimb => 'Què escales';

  @override
  String get whatYouClimbHint =>
      'Tria les teves disciplines i els graus que escales.';

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
  String get dateToBeDecided => 'Data per decidir';

  @override
  String dayAndMoreDays(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dies',
      one: '1 dia',
    );
    return '$day +$_temp0';
  }

  @override
  String get addDay => 'Afegeix un dia';

  @override
  String get leaveDateOpen => 'Deixa la data oberta';

  @override
  String get whenHelp =>
      'La data és opcional. Afegeix més dies per a una sortida més llarga.';

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
  String get adminTitle => 'Admin: persones';

  @override
  String get roles => 'Rols';

  @override
  String get rolesFailed => 'No s\'han pogut obtenir els teus rols de rbacr.';

  @override
  String get noRoles => 'Encara no tens rols a Grigri.';

  @override
  String get nudge => 'Recorda';

  @override
  String get nudged => 'Recordat';

  @override
  String get nudgeTooltip =>
      'Recorda al grup que respongui (un cop cada 12 hores)';

  @override
  String nudgeSent(String names) {
    return 'Recordatori enviat a $names';
  }

  @override
  String noticeNudgeTitle(String name) {
    return '$name espera la teva resposta';
  }

  @override
  String noticeNudgeBody(String plan) {
    return 'Per unir-se a $plan · accepta o rebutja al xat del grup';
  }

  @override
  String get attachMedia => 'Afegeix una foto o un vídeo';

  @override
  String get recordVideo => 'Grava un vídeo';

  @override
  String get chooseVideo => 'Tria un vídeo';

  @override
  String get photoMessage => 'Foto';

  @override
  String get videoMessage => 'Vídeo';

  @override
  String get removeAttachment => 'Treu l\'adjunt';

  @override
  String get uploadingMedia => 'S\'està pujant…';

  @override
  String get playVideo => 'Reprodueix el vídeo';

  @override
  String get videoUnavailable => 'Aquest vídeo no es pot reproduir.';

  @override
  String get mediaUnavailable => 'No disponible';

  @override
  String get errorMediaType =>
      'Fes servir una foto JPEG, PNG o WebP, o un vídeo MP4 o MOV.';

  @override
  String errorVideoTooBig(int mb) {
    return 'Els vídeos poden ocupar com a màxim $mb MB: envia\'n un de més curt.';
  }

  @override
  String matchScore(int percent, String level) {
    return 'Afinitat $percent% · $level';
  }

  @override
  String get matchLevelLongShot => 'poc probable';

  @override
  String get matchLevelPossible => 'possible';

  @override
  String get matchLevelGood => 'bona';

  @override
  String get matchLevelGreat => 'excel·lent';

  @override
  String get matchReasonOtherDiscipline => 'No escales aquesta disciplina';

  @override
  String get matchReasonTooHard =>
      'Els seus graus són molt per sobre dels teus';

  @override
  String get matchReasonTooEasy => 'Els seus graus són molt per sota dels teus';

  @override
  String get matchReasonStartsSoon => 'Comença en menys de 12 hores';

  @override
  String get matchReasonFar => 'A més de 100 km';

  @override
  String get matchReasonBigGroup => 'Cinc o més persones han de dir que sí';

  @override
  String get matchReasonCrowded => 'Hi ha deu o més persones esperant';

  @override
  String get matchReasonInGradesNearby => 'Als teus graus i a prop';

  @override
  String get matchReasonInGrades => 'Als teus graus';

  @override
  String get matchReasonCloseGrades => 'A un o dos graus dels teus';

  @override
  String get adminNoClimbersTitle => 'Encara ningú';

  @override
  String get adminNoClimbersMessage =>
      'Aquí surt tothom que té perfil, per bloquejar-lo o desbloquejar-lo.';

  @override
  String get block => 'Bloqueja';

  @override
  String get unblock => 'Desbloqueja';

  @override
  String get blocked => 'Bloquejat';

  @override
  String blockNameQuestion(String name) {
    return 'Vols bloquejar $name?';
  }

  @override
  String get blockMessage =>
      'No podrà fer servir Grigri fins que el desbloquegis, i els seus plans surten de Descobreix per a tothom.';

  @override
  String get blockedTitle => 'El teu compte està bloquejat';

  @override
  String get blockedMessage =>
      'Un administrador ha bloquejat el teu compte, i de moment no pots fer servir Grigri.';

  @override
  String get yourPics => 'Les teves fotos';

  @override
  String get grigriPics => 'GriGri Pics';

  @override
  String get yourPicsEmpty =>
      'Encara no hi ha fotos. Afegeix-ne una o envia-la al xat.';

  @override
  String get grigriPicsEmpty => 'Encara no hi ha GriGri Pics d\'aquest lloc.';

  @override
  String get addPlanPic => 'Afegeix una foto al pla';

  @override
  String get deletePic => 'Esborra la foto';

  @override
  String get deletePicQuestion => 'Vols esborrar aquesta foto?';

  @override
  String get deletePicMessage => 'Surt de les fotos del pla per a tothom.';

  @override
  String get deleteChatPicMessage =>
      'Surt de les fotos del pla; el xat la conserva.';

  @override
  String get delete => 'Esborra';

  @override
  String picCredit(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String picAddedBy(String name) {
    return 'Afegida per $name';
  }

  @override
  String picFromChat(String name) {
    return 'Enviada al xat per $name';
  }

  @override
  String get premiumTitle => 'Grigri Premium';

  @override
  String get premiumPitch =>
      'Anuncia\'t a Grigri: els teus anuncis surten entre els plans a Cerca de tothom. La resta no canvia.';

  @override
  String premiumMonthly(String price) {
    return '$price al mes';
  }

  @override
  String premiumYearly(String price) {
    return '$price l\'any';
  }

  @override
  String get premiumCheckoutHint =>
      'Pagues a la pàgina segura de Stripe, al navegador. Torna aquí quan acabis.';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium: es renova el $date';
  }

  @override
  String premiumEndsOn(String date) {
    return 'Premium: s\'acaba el $date';
  }

  @override
  String get premiumManage => 'Gestiona la subscripció';

  @override
  String get premiumUnavailable => 'Premium encara no està disponible.';

  @override
  String get premiumCheckRefresh => 'Ja he pagat: comprova-ho';

  @override
  String get premiumRestore => 'Restaura les compres';

  @override
  String premiumAppStoreTerms(String prices) {
    return 'Grigri Premium és una subscripció amb renovació automàtica: $prices. El pagament es carrega al teu ID d\'Apple quan confirmes. Es renova automàticament tret que la cancel·lis com a mínim 24 hores abans del final del període. Gestiona-la o cancel·la-la als ajustos del teu compte de l\'App Store.';
  }

  @override
  String get premiumPrivacyPolicy => 'Política de privadesa';

  @override
  String get premiumTermsOfUse => 'Condicions d\'ús (EULA)';

  @override
  String get premiumStoreUnavailable =>
      'Ara no es pot connectar amb l\'App Store.';

  @override
  String get premiumNothingToRestore =>
      'No hi ha cap subscripció de l\'App Store per restaurar.';

  @override
  String get premiumPurchaseFailed => 'La compra no s\'ha completat.';

  @override
  String get errorOpenLink => 'No s\'ha pogut obrir l\'enllaç.';

  @override
  String get tabAds => 'Anuncis';

  @override
  String get adTag => 'Anunci';

  @override
  String adBy(String name) {
    return 'Anunci de $name';
  }

  @override
  String get swipeOpen => 'Obre';

  @override
  String get swipeSkip => 'Salta';

  @override
  String get openAd => 'Obre l\'enllaç de l\'anunci';

  @override
  String get skipAd => 'Salta l\'anunci';

  @override
  String get shareAd => 'Comparteix l\'enllaç de l\'anunci';

  @override
  String get adsTitle => 'Els teus anuncis';

  @override
  String get adsEmptyTitle => 'Encara no hi ha anuncis';

  @override
  String get adsEmptyMessage =>
      'Afegeix un anunci: quan un admin l\'aprovi, sortirà entre els plans a Cerca de tothom.';

  @override
  String get newAd => 'Nou anunci';

  @override
  String get adStatusPending => 'Pendent de revisió';

  @override
  String get adStatusApproved => 'Aprovat: es mostra';

  @override
  String get adStatusRejected => 'Rebutjat';

  @override
  String get deleteAdQuestion => 'Vols eliminar aquest anunci?';

  @override
  String get deleteAdMessage => 'Desapareixerà de Cerca per sempre.';

  @override
  String get adTextLabel => 'Text sobre l\'anunci';

  @override
  String get adLinkLabel => 'Enllaç (https://…)';

  @override
  String get adLinkInvalid => 'Escriu una adreça web que comenci per https://';

  @override
  String get adAddMedia => 'Afegeix una foto o un vídeo';

  @override
  String get adRemoveMedia => 'Treu la foto o el vídeo';

  @override
  String get adVideoPicked => 'Vídeo';

  @override
  String get adNeedsContent => 'Afegeix text, una foto o un vídeo.';

  @override
  String get adSubmit => 'Envia a revisió';

  @override
  String get adSent => 'Enviat: un admin el revisarà.';

  @override
  String get adPreview => 'Previsualització';

  @override
  String get adsNeedPremium =>
      'El teu Premium s\'ha acabat: els teus anuncis no es mostren. Renova\'l al perfil.';

  @override
  String get adminUsersTab => 'Usuaris';

  @override
  String get adminAdsTab => 'Anuncis';

  @override
  String get adminAdsTitle => 'Admin';

  @override
  String get adsOnDiscover => 'A Cerca';

  @override
  String get adEveryOff => 'Sense anuncis';

  @override
  String adEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Un anunci cada $count plans',
      one: 'Un anunci després de cada pla',
    );
    return '$_temp0';
  }

  @override
  String get adApprove => 'Aprova';

  @override
  String get adReject => 'Rebutja';

  @override
  String get adminAdsEmpty => 'No hi ha anuncis aquí';

  @override
  String get routeFinder => 'Vies a la roca';

  @override
  String get routeFinderLoading => 'Preparant les parets d\'aquí…';

  @override
  String get routeFinderNoWalls =>
      'Encara no es coneix cap paret aquí. Registra la primera via.';

  @override
  String routeFinderSeen(String wall, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vies',
      one: '1 via',
      zero: 'encara sense vies',
    );
    return '$wall: $_temp0';
  }

  @override
  String get routeFinderPoint => 'Apunta la càmera a la paret';

  @override
  String get routeFinderSnap =>
      'Fes una foto de la paret per trobar-ne les vies';

  @override
  String get cameraUnavailable => 'La càmera no està disponible.';

  @override
  String get recordRoute => 'Registra una via';

  @override
  String get teachView => 'Aprèn aquesta vista';

  @override
  String get findRoutes => 'Troba vies';

  @override
  String get learnedView => 'Gràcies! Ara Grigri coneix millor aquesta paret.';

  @override
  String get needTwoBolts => 'Toca almenys dues xapes.';

  @override
  String get routeSaved => 'Via desada.';

  @override
  String get undoBolt => 'Desfés l\'última xapa';

  @override
  String get tapBolts => 'Toca cada xapa, des de terra fins a la reunió';

  @override
  String get tapBoltsNewWall =>
      'Roca nova: toca cada xapa, des de terra. Aquesta foto ensenyarà la paret a Grigri.';

  @override
  String get notRecognized => 'Grigri no ha reconegut aquesta paret.';

  @override
  String get saveRoute => 'Desa la via';

  @override
  String get newWallNote =>
      'Una paret nova: aquesta foto ensenyarà a Grigri com és.';

  @override
  String get wallName => 'Paret';

  @override
  String get routeName => 'Nom de la via';

  @override
  String get routeScale => 'Via';

  @override
  String get boulderScale => 'Bloc';

  @override
  String get routeGrade => 'Grau';

  @override
  String kmAway(String km) {
    return '$km km';
  }

  @override
  String get sectionWhoCanJoin => 'Qui s\'hi pot unir';

  @override
  String get planTypePrivate => 'Privat';

  @override
  String get planTypeOpen => 'Obert';

  @override
  String get planTypeGuided => 'Guiat';

  @override
  String get planTypePrivateHint => 'Tot el grup diu que sí a cada nou.';

  @override
  String get planTypeOpenHint =>
      'Qualsevol s\'hi pot unir al moment, sense esperar un sí.';

  @override
  String get planTypeGuidedHint =>
      'Tu guies i els escaladors et paguen. Només tu respons les sol·licituds.';

  @override
  String get pricePerClimber => 'Preu per escalador';

  @override
  String get priceInvalid =>
      'Posa un preu més gran que 0, amb dos decimals com a màxim';

  @override
  String get currency => 'Moneda';

  @override
  String guidedPrice(String price) {
    return 'Guiat · $price';
  }

  @override
  String get paidToGuide => 'Es paga al guia, no a través de Grigri.';

  @override
  String get theGuideDecides => 'Decideix el guia';

  @override
  String get openJoinAtOnce => 'Obert: uneix-te al moment';

  @override
  String get signInBadge => '100% gratuït';

  @override
  String get signInHeadline => 'Uneix-te a un pla d’escalada.';

  @override
  String get signInFreeLine =>
      'Gratuït per a tothom: sense targeta, sense subscripció.';

  @override
  String get signInStampJoin => 'M’HI APUNTO';

  @override
  String get signInDeckWhen => 'Aquest dissabte · Esportiva · 6b–7a';

  @override
  String get signInDeckWho => 'Mara, Jonas i 1 més';

  @override
  String get signInHowTitle => 'Com funciona';

  @override
  String get signInStep1Title => 'Fes un pla';

  @override
  String get signInStep1Body =>
      'On, quan i quins graus: una escola, un dissabte, de 6a a 7a.';

  @override
  String get signInStep2Title => 'Llisca a la dreta';

  @override
  String get signInStep2Body =>
      'T’agrada un pla? Llisca a la dreta. El grup admet els nous d’un en un, quan tothom diu que sí.';

  @override
  String get signInStep3Title => 'Escaleu junts';

  @override
  String get signInStep3Body =>
      'Cada match obre el xat de grup del pla: la corda, el cotxe i el cafè.';

  @override
  String get signInFreeTitle => 'Gratuït. De debò.';

  @override
  String get signInFree1 => 'Plans i lliscar';

  @override
  String get signInFree2 => 'Matches i xats de grup';

  @override
  String get signInFree3 => 'Fotos de les escoles';

  @override
  String get signInFree4 => 'Sense targeta per registrar-te';

  @override
  String get signInFreePremium =>
      'Premium és opcional: només serveix per anunciar-se a Grigri i per al cercador de vies. Escalar amb Grigri no costa res.';

  @override
  String get signInFinalTitle =>
      'El pla d’escalada d’aquest cap de setmana és a un lliscament.';

  @override
  String get signInJoinFree => 'Uneix-te gratis amb Google';

  @override
  String signInPhotoBy(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String get signInDeckWhen2 => 'Diumenge · Via llarga · 6a–6b';

  @override
  String get signInDeckWho2 => 'Iker i Lea';

  @override
  String get signInDeckWhen3 => 'El cap de setmana que ve · Bloc · 6C–7A';

  @override
  String get signInDeckWho3 => 'Noor, Tomás i 2 més';

  @override
  String get privacyPolicy => 'Política de privadesa';

  @override
  String get support => 'Suport';

  @override
  String get deleteAccount => 'Elimina el compte';

  @override
  String get deleteAccountQuestion => 'Vols eliminar el teu compte?';

  @override
  String get deleteAccountMessage =>
      'Elimina el teu compte de Grigri per sempre: el teu perfil i les teves fotos, els teus missatges i fotos als xats de grup, les teves sol·licituds i els teus anuncis. Surts de tots els teus plans: als que organitzes, una altra persona del pla passa a organitzar-lo, i un pla on només hi ets tu s\'acaba. El Premium pagat aquí amb targeta es cancel·la al moment, sense reemborsament del temps que queda. Una subscripció comprada a través d\'Apple s\'ha de cancel·lar a la Configuració de l\'iPhone. Es tanca la teva sessió a tots els dispositius.';

  @override
  String get deleteAccountUnderstand => 'Entenc que no es pot desfer';

  @override
  String get deleteAccountConfirm => 'Elimina per sempre';

  @override
  String get errorDeleteAccount =>
      'No s\'ha pogut eliminar el teu compte. Torna-ho a provar.';

  @override
  String get moreActions => 'Més';

  @override
  String get report => 'Denuncia';

  @override
  String blockPerson(String name) {
    return 'Bloqueja $name';
  }

  @override
  String get reportTitle => 'Per què ho denuncies?';

  @override
  String get reportReasonSpam => 'Correu brossa';

  @override
  String get reportReasonHarassment => 'Assetjament';

  @override
  String get reportReasonInappropriate => 'Contingut inadequat';

  @override
  String get reportReasonFake => 'Perfil fals';

  @override
  String get reportReasonOther => 'Un altre motiu';

  @override
  String get reportDetailsHint => 'Res més que hàgim de saber? (opcional)';

  @override
  String get reportSend => 'Envia la denúncia';

  @override
  String get reportThanks => 'Gràcies, ho revisarem en menys de 24 hores.';

  @override
  String get blockPersonMessage =>
      'No veureu els plans de l’altre, cap dels dos podrà demanar unir-se a un pla on sigui l’altre, les seves sol·licituds als teus plans es rebutgen i no veuràs els seus missatges. No se li diu.';

  @override
  String blockedPersonDone(String name) {
    return 'Has bloquejat $name.';
  }

  @override
  String get blockedPeopleTitle => 'Persones bloquejades';

  @override
  String get blockedPeopleEmpty => 'No has bloquejat ningú.';

  @override
  String get adminReportsTab => 'Denúncies';

  @override
  String get adminReportsEmpty => 'No hi ha denúncies per revisar.';

  @override
  String reportedBy(String name) {
    return 'Denunciat per $name';
  }

  @override
  String get reportKindProfile => 'Perfil';

  @override
  String get reportKindPlan => 'Pla';

  @override
  String get reportKindMessage => 'Missatge del xat';

  @override
  String get reportKindPic => 'Foto del pla';

  @override
  String get reportKindAd => 'Anunci';

  @override
  String get reportDismiss => 'Descarta';

  @override
  String get reportRemove => 'Treu el contingut';

  @override
  String get reportBlock => 'Bloqueja l’escalador';

  @override
  String get noticeReportsTitle => 'Noves denúncies per revisar';

  @override
  String get noticeReportsBody =>
      'Admin → Denúncies · respon en menys de 24 hores';

  @override
  String get errorObjectionable =>
      'Mantén un to amable: hi ha paraules que Grigri no permet.';

  @override
  String get areaGuide => 'Guia de la zona';

  @override
  String get guideAccess => 'Accés';

  @override
  String get guideClimbing => 'Tipus d\'escalada';

  @override
  String get guideRock => 'Roca';

  @override
  String get guideRoutes => 'Vies';

  @override
  String get guideSeason => 'Època';

  @override
  String get guideTips => 'Consells i advertències';

  @override
  String get guideReading => 'Bibliografia';

  @override
  String get guideSectors => 'Sectors';

  @override
  String get guideClimbs => 'Vies destacades';

  @override
  String get guideClosures => 'Restriccions';

  @override
  String get guideClosedNow => 'Tancat ara';

  @override
  String get guideAreas => 'Escoles d\'escalada';

  @override
  String get guideAdvice => 'Abans d\'escalar';

  @override
  String get guideServices => 'Serveis';

  @override
  String get guideLinks => 'Enllaços útils';

  @override
  String get guideBibliography => 'Bibliografia';

  @override
  String get guideOpenAll => 'La guia sencera';

  @override
  String guideSource(String title, String publisher, int year) {
    return 'De «$title», $publisher, $year.';
  }

  @override
  String guideCredits(String text, String photos) {
    return 'Text: $text · Fotos: $photos';
  }

  @override
  String guideClosure(String sector, String from, String to, String reason) {
    return '$sector: tancat $from – $to ($reason)';
  }

  @override
  String get guideAccessMap => 'Mapa d\'accessos';
}
