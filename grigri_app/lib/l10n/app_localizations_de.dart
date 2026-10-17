// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get disciplineSport => 'Sportklettern';

  @override
  String get disciplineTrad => 'Trad';

  @override
  String get disciplineBouldering => 'Bouldern';

  @override
  String get disciplineGym => 'Halle';

  @override
  String get gradeSystemEuropean => 'Europäisch';

  @override
  String get gradeSystemAmerican => 'Amerikanisch';

  @override
  String get gearRope => 'Seil';

  @override
  String get gearQuickdraws => 'Expressen';

  @override
  String get gearRack => 'Mobile Sicherungen';

  @override
  String get gearCrashPad => 'Crashpad';

  @override
  String get gearCar => 'Auto';

  @override
  String get gearBelayDevice => 'Sicherungsgerät';

  @override
  String get gearHarness => 'Klettergurt';

  @override
  String get gearHelmet => 'Helm';

  @override
  String get gearShoes => 'Kletterschuhe';

  @override
  String get yourGear => 'Deine Ausrüstung';

  @override
  String get editGear => 'Ausrüstung bearbeiten';

  @override
  String get addGear => 'Ausrüstung hinzufügen';

  @override
  String get gearEmpty =>
      'Füg die Ausrüstung hinzu, die du hast, mit Fotos: Die Gruppen deiner Pläne sehen sie und prüfen, ob sie alles haben.';

  @override
  String get gearShared => 'Für die Gruppe';

  @override
  String get gearSharedHint =>
      'Die Gruppe teilt sie: Ein Seil reicht für zwei.';

  @override
  String get gearPersonal => 'Deine eigene';

  @override
  String get gearPersonalHint => 'Alle brauchen ihre eigene.';

  @override
  String get gearPhotos => 'Fotos';

  @override
  String get planGearAllSet => 'Die Gruppe hat alles, was sie braucht.';

  @override
  String planGearMissing(String items) {
    return 'Es fehlt Ausrüstung: $items';
  }

  @override
  String get planGearGym =>
      'Die Halle hat Seile und Matten und verleiht den Rest.';

  @override
  String get planGearGuided =>
      'Der Guide bringt die Ausrüstung der Gruppe mit: Prüf, ob du deine eigene hast.';

  @override
  String get noGearListed => 'Keine Ausrüstung angegeben';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get more => 'Mehr';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get signOut => 'Abmelden';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get retry => 'Wiederholen';

  @override
  String get newPlan => 'Neuer Plan';

  @override
  String get you => 'Du';

  @override
  String get youLower => 'du';

  @override
  String get someone => 'Jemand';

  @override
  String climberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen',
      one: '1 Person',
    );
    return '$_temp0';
  }

  @override
  String saidYesCount(int yes, int total) {
    return '$yes von $total haben zugesagt';
  }

  @override
  String get declined => 'Abgelehnt';

  @override
  String get pending => 'Ausstehend';

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get errorGeneric => 'Etwas ist schiefgelaufen.';

  @override
  String errorStatus(int status) {
    return 'Etwas ist schiefgelaufen ($status).';
  }

  @override
  String get errorTimeout => 'Der Server hat zu lange nicht geantwortet.';

  @override
  String get errorUnreachable => 'Der Server ist nicht erreichbar.';

  @override
  String get errorPhotoTimeout =>
      'Das Hochladen des Fotos hat zu lange gedauert.';

  @override
  String get errorPhotoUnreachable =>
      'Das Foto konnte nicht hochgeladen werden.';

  @override
  String errorPhotoStatus(int status) {
    return 'Das Hochladen des Fotos ist fehlgeschlagen ($status).';
  }

  @override
  String get errorPhotoType => 'Nimm ein Foto im Format JPEG, PNG oder WebP.';

  @override
  String get errorSignedOut => 'Abgemeldet: Bitte melde dich erneut an.';

  @override
  String get errorSignIn =>
      'Anmeldung mit Google fehlgeschlagen. Versuch es noch einmal.';

  @override
  String get errorSignInApple =>
      'Anmeldung mit Apple fehlgeschlagen. Versuch es noch einmal.';

  @override
  String get errorSession =>
      'Anmeldung fehlgeschlagen. Versuch es noch einmal.';

  @override
  String get errorSignOutEverywhere =>
      'Abmelden auf allen Geräten fehlgeschlagen. Versuch es noch einmal.';

  @override
  String get loadFailedTitle => 'Dein Profil konnte nicht geladen werden';

  @override
  String get signInTagline =>
      'Mach einen Plan oder wisch bei einem nach rechts, und klettert zusammen.';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get signInWithApple => 'Mit Apple anmelden';

  @override
  String get tabDiscover => 'Suche';

  @override
  String get tabPlans => 'Pläne';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabNotifications => 'Infos';

  @override
  String get tabProfile => 'Ich';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'Der Plan';

  @override
  String get demoTag => 'Demo';

  @override
  String get demoNotice => 'Demo: erfundene Personen und Pläne.';

  @override
  String get yourGrades => 'Dein Grad';

  @override
  String get profileClimbs => 'Klettert';

  @override
  String get profileGear => 'Ausrüstung';

  @override
  String gearPhotoOf(String name, int number) {
    return 'Ausrüstung von $name, Foto $number';
  }

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'Systemsprache';

  @override
  String get profileTitle => 'Profil';

  @override
  String get signOutQuestion => 'Abmelden?';

  @override
  String get signOutMessage =>
      'Dein Profil, deine Pläne und Chats bleiben gespeichert; melde dich wieder an, um sie zu sehen.';

  @override
  String get signOutEverywhere => 'Überall abmelden';

  @override
  String get signOutEverywhereQuestion => 'Überall abmelden?';

  @override
  String get signOutEverywhereMessage =>
      'Meldet dich auf allen Handys und Browsern ab, auf denen du angemeldet bist, auch auf diesem. Dein Profil, deine Pläne und Chats bleiben gespeichert.';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get profileFootnote =>
      'Dein Profil handelt von dir: was du kletterst und welche Ausrüstung du hast. Wann und wo gehören zu Plänen, die du separat unter Pläne erstellst.';

  @override
  String get takePhoto => 'Foto aufnehmen';

  @override
  String get choosePhoto => 'Foto auswählen';

  @override
  String get removePhoto => 'Foto entfernen';

  @override
  String get photoFailed => 'Das Foto konnte nicht geladen werden';

  @override
  String get addPhoto => 'Foto hinzufügen';

  @override
  String get changePhoto => 'Foto ändern';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameRequired => 'Bitte gib deinen Namen ein';

  @override
  String get ageLabel => 'Alter (optional)';

  @override
  String ageRange(int min, int max) {
    return '$min bis $max';
  }

  @override
  String get bioLabel => 'Über dich';

  @override
  String get gradeSystem => 'Bewertungssystem';

  @override
  String get gradeSystemHint =>
      'Wie Grade in der App geschrieben werden, hier für eine Route und einen Boulder.';

  @override
  String get whatYouClimb => 'Was du kletterst';

  @override
  String get whatYouClimbHint =>
      'Wähl deine Disziplinen und die Grade, die du kletterst.';

  @override
  String get gearHint => 'Füg auch Fotos davon hinzu.';

  @override
  String gearPhoto(int number) {
    return 'Ausrüstungsfoto $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Ausrüstungsfoto $number entfernen';
  }

  @override
  String get addGearPhoto => 'Ausrüstungsfoto hinzufügen';

  @override
  String get whereYouClimb => 'Wo du kletterst';

  @override
  String get whereYouClimbHint =>
      'Pläne in der Nähe kommen unter Entdecken zuerst. Nur du siehst das.';

  @override
  String get setYourLocation => 'Standort festlegen';

  @override
  String get yourLocation => 'Dein Standort';

  @override
  String get clearYourLocation => 'Standort entfernen';

  @override
  String removeArea(String name) {
    return '$name entfernen';
  }

  @override
  String get addArea => 'Gebiet hinzufügen';

  @override
  String get locationSearchLabel =>
      'Ein Klettergebiet oder eine Halle in der Nähe';

  @override
  String get search => 'Suchen';

  @override
  String get locationPrivacy =>
      'Auf etwa 1 km gerundet, und nur du siehst ihn.';

  @override
  String placesAttribution(String attribution) {
    return 'Orte: $attribution';
  }

  @override
  String get loadingPlaces => 'Orte werden geladen…';

  @override
  String get noPlacesFound => 'Keine Orte gefunden';

  @override
  String get useCurrentLocation => 'Meinen aktuellen Standort verwenden';

  @override
  String get locationNotFound =>
      'Dein Standort ließ sich nicht bestimmen. Such stattdessen einen Ort.';

  @override
  String nearPlace(String place) {
    return 'In der Nähe von $place';
  }

  @override
  String get currentLocation => 'Wo ich bin';

  @override
  String get setWhereYouClimbHint =>
      'Leg fest, wo du kletterst, um Pläne in deiner Nähe zuerst zu sehen.';

  @override
  String get setAction => 'Festlegen';

  @override
  String get discoverTitle => 'Pläne entdecken';

  @override
  String get askedToJoinSent =>
      'Anfrage gesendet. Du bekommst einen Hinweis, sobald du dabei bist.';

  @override
  String get noPlansToJoinTitle => 'Gerade keine Pläne zum Mitmachen';

  @override
  String get noPlansToJoinMessage =>
      'Noch hat niemand einen passenden Plan. Mach deinen eigenen: Wer passt, fragt an.';

  @override
  String get swipeJoin => 'Dabei';

  @override
  String get swipePass => 'Weiter';

  @override
  String get pass => 'Überspringen';

  @override
  String get askToJoin => 'Mitmachen anfragen';

  @override
  String get sharePlan => 'Diesen Plan teilen';

  @override
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  ) {
    return 'Kletterplan auf Grigri: $discipline in $place, $when. $link';
  }

  @override
  String get organizedBy => 'Organisiert von';

  @override
  String get alsoInGroup => 'Auch in der Gruppe';

  @override
  String get showGroup => 'Gruppe zeigen';

  @override
  String get hideGroup => 'Gruppe ausblenden';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get noChatsTitle => 'Noch keine Chats';

  @override
  String get noChatsMessage =>
      'Jeder Plan, bei dem du dabei bist, hat einen Gruppenchat. Mach einen Plan oder frag bei einem an, und sein Chat erscheint hier.';

  @override
  String get findPlan => 'Plan finden';

  @override
  String messagePreview(String author, String text) {
    return '$author: $text';
  }

  @override
  String toAnswer(int count) {
    return '$count offen';
  }

  @override
  String get notInGroupTitle => 'Nicht in dieser Gruppe';

  @override
  String get notInGroupMessage =>
      'Du hast diesen Plan verlassen, sein Chat ist geschlossen.';

  @override
  String get messageHint => 'Nachricht an die Gruppe';

  @override
  String get send => 'Senden';

  @override
  String get wantsToJoinYourAnswer => 'Will mitmachen · deine Antwort';

  @override
  String declineName(String name) {
    return '$name ablehnen';
  }

  @override
  String acceptName(String name) {
    return '$name annehmen';
  }

  @override
  String askedToJoinAt(String time) {
    return 'Anfrage · $time';
  }

  @override
  String noGradesYet(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Noch kein Grad im Sportklettern',
      'trad': 'Noch kein Grad im Trad',
      'bouldering': 'Noch kein Grad im Bouldern',
      'gym': 'Noch kein Grad in der Halle',
      'other': 'Noch kein Grad',
    });
    return '$_temp0';
  }

  @override
  String get joined => 'Dabei';

  @override
  String get closed => 'Geschlossen';

  @override
  String namesSaidYes(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zugesagt: $names',
      one: 'Zugesagt: $names',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'offen: $names';
  }

  @override
  String get itsAMatch => 'It\'s a Match!';

  @override
  String get matchEveryoneSaidYes =>
      'Alle in der Gruppe haben zugesagt. Ihr klettert zusammen:';

  @override
  String matchJoinsGroup(String name) {
    return '$name ist jetzt in der Gruppe:';
  }

  @override
  String get openGroupChat => 'Gruppenchat öffnen';

  @override
  String get keepSwiping => 'Weiter wischen';

  @override
  String get notificationsTitle => 'Hinweise';

  @override
  String get nothingYetTitle => 'Noch nichts';

  @override
  String get nothingYetMessage =>
      'Wenn jemand bei einem deiner Pläne mitmachen will oder eine Gruppe auf deine Anfrage antwortet, erfährst du es hier.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name will mitmachen';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · antworte im Gruppenchat';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'Du bist dabei: $plan';
  }

  @override
  String get noticeAcceptedBody =>
      'Die Gruppe hat dich angenommen. Sag Hallo im Chat.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Diesmal nicht: $plan';
  }

  @override
  String get noticeDeclinedBody => 'Die Gruppe hat deine Anfrage abgelehnt.';

  @override
  String get newTag => 'Neu';

  @override
  String get planGoneTitle => 'Plan nicht mehr da';

  @override
  String get planGoneMessage =>
      'Alle haben diesen Plan verlassen, oder er ist nicht mehr offen.';

  @override
  String get yourPlan => 'Dein Plan';

  @override
  String get planTitle => 'Plan';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get declinedGroupSaidNo => 'Abgelehnt: Die Gruppe hat abgesagt';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'Ausstehend: $yes von $total haben zugesagt';
  }

  @override
  String theGroupCount(int count) {
    return 'Die Gruppe · $count';
  }

  @override
  String get organizer => 'Organisator';

  @override
  String get member => 'Mitglied';

  @override
  String get askingToJoin => 'Anfragen';

  @override
  String get youSaidYes => 'Du hast zugesagt';

  @override
  String get answerInChat => 'Antworte im Chat';

  @override
  String get groupChat => 'Gruppenchat';

  @override
  String get cancelPlan => 'Plan absagen';

  @override
  String get cancelPlanQuestion => 'Plan absagen?';

  @override
  String get cancelPlanMessage => 'Der Plan und sein Chat werden gelöscht.';

  @override
  String get cancelPlanOthersMessage =>
      'Er verschwindet aus deinen Plänen und Chats; die anderen behalten ihn. Du kannst später nicht wieder beitreten.';

  @override
  String get cancelPlanOrganizerMessage =>
      'Er verschwindet aus deinen Plänen und Chats; die anderen behalten ihn, und eine zufällig gewählte Person organisiert ihn. Du kannst später nicht wieder beitreten.';

  @override
  String get keepPlan => 'Behalten';

  @override
  String get confirmCancelPlan => 'Absagen';

  @override
  String get editPlan => 'Plan bearbeiten';

  @override
  String get pickFutureTime => 'Wähl eine Zeit in der Zukunft.';

  @override
  String get sectorLabel => 'Sektor, Klettergebiet oder Halle';

  @override
  String get sectorHint => 'Suchen oder eintippen';

  @override
  String sectorsAttribution(String attribution) {
    return 'Sektoren: $attribution';
  }

  @override
  String get whereRequired => 'Wo kletterst du?';

  @override
  String get sectionDiscipline => 'Disziplin';

  @override
  String get sectionWhere => 'Wo';

  @override
  String get sectionWhen => 'Wann';

  @override
  String get dateToBeDecided => 'Datum noch offen';

  @override
  String dayAndMoreDays(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$day +$_temp0';
  }

  @override
  String get addDay => 'Tag hinzufügen';

  @override
  String get leaveDateOpen => 'Datum offen lassen';

  @override
  String get whenHelp =>
      'Das Datum ist optional. Füge für eine längere Tour weitere Tage hinzu.';

  @override
  String get sectionGrades => 'Grade';

  @override
  String get sectionNotes => 'Notizen';

  @override
  String get notesHint =>
      'Treffpunkt, Plätze im Auto, die Routen, die du im Kopf hast…';

  @override
  String get publishPlan => 'Plan veröffentlichen';

  @override
  String get yourPlans => 'Deine Pläne';

  @override
  String get noPlansYetTitle => 'Noch keine Pläne';

  @override
  String get noPlansYetMessage =>
      'Mach einen Plan (was, wo, wann), und passende Leute fragen an. Oder wisch unter Entdecken bei einem nach rechts.';

  @override
  String get plansClimbing => 'Dabei';

  @override
  String get plansAskedToJoin => 'Angefragt';

  @override
  String get organizing => 'Du organisierst';

  @override
  String get accepted => 'Angenommen';

  @override
  String toReview(int count) {
    return '$count zu prüfen';
  }

  @override
  String get groupSaidNo => 'Die Gruppe hat abgesagt';

  @override
  String waitingForNames(String names) {
    return 'Wartet auf $names';
  }

  @override
  String get dismiss => 'Ausblenden';

  @override
  String get adminTitle => 'Admin: Personen';

  @override
  String get roles => 'Rollen';

  @override
  String get rolesFailed =>
      'Deine Rollen konnten nicht von rbacr geladen werden.';

  @override
  String get noRoles => 'Noch keine Rollen in Grigri.';

  @override
  String get nudge => 'Erinnern';

  @override
  String get nudged => 'Erinnert';

  @override
  String get nudgeTooltip =>
      'Erinnere die Gruppe an eine Antwort (einmal alle 12 Stunden)';

  @override
  String nudgeSent(String names) {
    return 'Erinnerung an $names gesendet';
  }

  @override
  String noticeNudgeTitle(String name) {
    return '$name wartet auf deine Antwort';
  }

  @override
  String noticeNudgeBody(String plan) {
    return 'Um bei $plan mitzumachen · nimm im Gruppenchat an oder lehne ab';
  }

  @override
  String get attachMedia => 'Foto oder Video hinzufügen';

  @override
  String get recordVideo => 'Video aufnehmen';

  @override
  String get chooseVideo => 'Video auswählen';

  @override
  String get photoMessage => 'Foto';

  @override
  String get videoMessage => 'Video';

  @override
  String get removeAttachment => 'Anhang entfernen';

  @override
  String get uploadingMedia => 'Wird hochgeladen…';

  @override
  String get playVideo => 'Video abspielen';

  @override
  String get videoUnavailable => 'Dieses Video kann nicht abgespielt werden.';

  @override
  String get mediaUnavailable => 'Nicht verfügbar';

  @override
  String get errorMediaType =>
      'Nimm ein Foto im Format JPEG, PNG oder WebP oder ein Video im Format MP4 oder MOV.';

  @override
  String errorVideoTooBig(int mb) {
    return 'Videos dürfen höchstens $mb MB groß sein: Schick ein kürzeres.';
  }

  @override
  String matchScore(int percent, String level) {
    return 'Passung $percent% · $level';
  }

  @override
  String get matchLevelLongShot => 'unwahrscheinlich';

  @override
  String get matchLevelPossible => 'möglich';

  @override
  String get matchLevelGood => 'gut';

  @override
  String get matchLevelGreat => 'sehr gut';

  @override
  String get matchReasonOtherDiscipline => 'Du kletterst diese Disziplin nicht';

  @override
  String get matchReasonTooHard => 'Die Grade liegen deutlich über deinen';

  @override
  String get matchReasonTooEasy => 'Die Grade liegen deutlich unter deinen';

  @override
  String get matchReasonStartsSoon => 'Beginnt in weniger als 12 Stunden';

  @override
  String get matchReasonFar => 'Mehr als 100 km entfernt';

  @override
  String get matchReasonBigGroup =>
      'Fünf oder mehr Leute müssen alle zustimmen';

  @override
  String get matchReasonCrowded => 'Zehn oder mehr andere warten';

  @override
  String get matchReasonInGradesNearby => 'In deinen Graden und in der Nähe';

  @override
  String get matchReasonInGrades => 'In deinen Graden';

  @override
  String get matchReasonCloseGrades => 'Ein bis zwei Grade von deinen entfernt';

  @override
  String get adminNoClimbersTitle => 'Noch niemand';

  @override
  String get adminNoClimbersMessage =>
      'Hier erscheint jede Person mit Profil, zum Sperren oder Entsperren.';

  @override
  String get block => 'Sperren';

  @override
  String get unblock => 'Entsperren';

  @override
  String get blocked => 'Gesperrt';

  @override
  String blockNameQuestion(String name) {
    return '$name sperren?';
  }

  @override
  String get blockMessage =>
      'Die Person kann Grigri nicht nutzen, bis du sie entsperrst, und ihre Pläne verschwinden für alle aus Entdecken.';

  @override
  String get blockedTitle => 'Dein Konto ist gesperrt';

  @override
  String get blockedMessage =>
      'Ein Admin hat dein Konto gesperrt, daher kannst du Grigri vorerst nicht nutzen.';

  @override
  String get yourPics => 'Deine Fotos';

  @override
  String get grigriPics => 'GriGri Pics';

  @override
  String get yourPicsEmpty =>
      'Noch keine Fotos. Füge eins hinzu oder schick eins im Chat.';

  @override
  String get grigriPicsEmpty => 'Noch keine GriGri Pics von diesem Ort.';

  @override
  String get addPlanPic => 'Foto zum Plan hinzufügen';

  @override
  String get deletePic => 'Foto löschen';

  @override
  String get deletePicQuestion => 'Dieses Foto löschen?';

  @override
  String get deletePicMessage =>
      'Es verschwindet für alle aus den Fotos des Plans.';

  @override
  String get deleteChatPicMessage =>
      'Es verschwindet aus den Fotos des Plans; der Chat behält es.';

  @override
  String get delete => 'Löschen';

  @override
  String picCredit(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String picAddedBy(String name) {
    return 'Hinzugefügt von $name';
  }

  @override
  String picFromChat(String name) {
    return 'Im Chat gesendet von $name';
  }

  @override
  String get premiumTitle => 'Grigri Premium';

  @override
  String get premiumPitch =>
      'Wirb auf Grigri: Deine Anzeigen erscheinen bei allen in der Suche zwischen den Plänen. Sonst bleibt alles gleich.';

  @override
  String premiumMonthly(String price) {
    return '$price im Monat';
  }

  @override
  String premiumYearly(String price) {
    return '$price im Jahr';
  }

  @override
  String get premiumCheckoutHint =>
      'Du bezahlst auf der sicheren Seite von Stripe in deinem Browser. Komm danach hierher zurück.';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium: verlängert sich am $date';
  }

  @override
  String premiumEndsOn(String date) {
    return 'Premium: endet am $date';
  }

  @override
  String get premiumManage => 'Abo verwalten';

  @override
  String get premiumUnavailable => 'Premium ist noch nicht verfügbar.';

  @override
  String get premiumCheckRefresh => 'Bezahlt: erneut prüfen';

  @override
  String get premiumRestore => 'Käufe wiederherstellen';

  @override
  String premiumAppStoreTerms(String prices) {
    return 'Grigri Premium ist ein automatisch verlängertes Abo: $prices. Die Zahlung wird bei der Bestätigung über deine Apple-ID abgerechnet. Es verlängert sich automatisch, wenn du es nicht mindestens 24 Stunden vor Ende des Zeitraums kündigst. Verwalten oder kündigen kannst du es in den Einstellungen deines App-Store-Accounts.';
  }

  @override
  String get premiumPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get premiumTermsOfUse => 'Nutzungsbedingungen (EULA)';

  @override
  String get premiumStoreUnavailable =>
      'Der App Store ist gerade nicht erreichbar.';

  @override
  String get premiumNothingToRestore =>
      'Kein App-Store-Abo zum Wiederherstellen.';

  @override
  String get premiumPurchaseFailed => 'Der Kauf ist nicht zustande gekommen.';

  @override
  String get errorOpenLink => 'Der Link ließ sich nicht öffnen.';

  @override
  String get tabAds => 'Anzeigen';

  @override
  String get adTag => 'Anzeige';

  @override
  String adBy(String name) {
    return 'Anzeige von $name';
  }

  @override
  String get swipeOpen => 'Öffnen';

  @override
  String get swipeSkip => 'Weiter';

  @override
  String get openAd => 'Link der Anzeige öffnen';

  @override
  String get skipAd => 'Anzeige überspringen';

  @override
  String get shareAd => 'Link der Anzeige teilen';

  @override
  String get adsTitle => 'Deine Anzeigen';

  @override
  String get adsEmptyTitle => 'Noch keine Anzeigen';

  @override
  String get adsEmptyMessage =>
      'Füge eine Anzeige hinzu: Sobald ein Admin sie freigibt, erscheint sie bei allen in der Suche zwischen den Plänen.';

  @override
  String get newAd => 'Neue Anzeige';

  @override
  String get adStatusPending => 'Wartet auf Prüfung';

  @override
  String get adStatusApproved => 'Freigegeben: wird gezeigt';

  @override
  String get adStatusRejected => 'Abgelehnt';

  @override
  String get deleteAdQuestion => 'Diese Anzeige löschen?';

  @override
  String get deleteAdMessage => 'Sie verschwindet endgültig aus der Suche.';

  @override
  String get adTextLabel => 'Text auf der Anzeige';

  @override
  String get adLinkLabel => 'Link (https://…)';

  @override
  String get adLinkInvalid =>
      'Gib eine Webadresse ein, die mit https:// beginnt';

  @override
  String get adAddMedia => 'Foto oder Video hinzufügen';

  @override
  String get adRemoveMedia => 'Foto oder Video entfernen';

  @override
  String get adVideoPicked => 'Video';

  @override
  String get adNeedsContent => 'Füge Text, ein Foto oder ein Video hinzu.';

  @override
  String get adSubmit => 'Zur Prüfung senden';

  @override
  String get adSent => 'Gesendet: Ein Admin prüft sie.';

  @override
  String get adPreview => 'Vorschau';

  @override
  String get adsNeedPremium =>
      'Dein Premium ist abgelaufen: Deine Anzeigen werden nicht gezeigt. Verlängere es in deinem Profil.';

  @override
  String get adminUsersTab => 'Nutzer';

  @override
  String get adminAdsTab => 'Anzeigen';

  @override
  String get adminAdsTitle => 'Admin';

  @override
  String get adsOnDiscover => 'In der Suche';

  @override
  String get adEveryOff => 'Keine Anzeigen';

  @override
  String adEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eine Anzeige alle $count Pläne',
      one: 'Eine Anzeige nach jedem Plan',
    );
    return '$_temp0';
  }

  @override
  String get adApprove => 'Freigeben';

  @override
  String get adReject => 'Ablehnen';

  @override
  String get adminAdsEmpty => 'Keine Anzeigen hier';

  @override
  String get routeFinder => 'Routen am Fels';

  @override
  String get routeFinderLoading => 'Die Wände hier werden vorbereitet…';

  @override
  String get routeFinderNoWalls =>
      'Hier ist noch keine Wand bekannt. Nimm die erste Route auf.';

  @override
  String routeFinderSeen(String wall, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Routen',
      one: '1 Route',
      zero: 'noch keine Routen',
    );
    return '$wall: $_temp0';
  }

  @override
  String get routeFinderPoint => 'Richte die Kamera auf die Wand';

  @override
  String get routeFinderSnap =>
      'Fotografiere die Wand, um ihre Routen zu finden';

  @override
  String get cameraUnavailable => 'Die Kamera ist nicht verfügbar.';

  @override
  String get recordRoute => 'Route aufnehmen';

  @override
  String get teachView => 'Diese Ansicht lernen';

  @override
  String get findRoutes => 'Routen finden';

  @override
  String get learnedView => 'Danke! Grigri kennt diese Wand jetzt besser.';

  @override
  String get needTwoBolts => 'Tippe mindestens zwei Haken an.';

  @override
  String get routeSaved => 'Route gespeichert.';

  @override
  String get undoBolt => 'Letzten Haken zurücknehmen';

  @override
  String get tapBolts => 'Tippe jeden Haken an, vom Boden bis zum Umlenker';

  @override
  String get tapBoltsNewWall =>
      'Neuer Fels: Tippe jeden Haken an, vom Boden aus. Dieses Foto bringt Grigri die Wand bei.';

  @override
  String get notRecognized => 'Grigri hat diese Wand nicht erkannt.';

  @override
  String get saveRoute => 'Route speichern';

  @override
  String get newWallNote =>
      'Eine neue Wand: Dieses Foto zeigt Grigri, wie sie aussieht.';

  @override
  String get wallName => 'Wand';

  @override
  String get routeName => 'Name der Route';

  @override
  String get routeScale => 'Route';

  @override
  String get boulderScale => 'Boulder';

  @override
  String get routeGrade => 'Grad';

  @override
  String kmAway(String km) {
    return '$km km';
  }

  @override
  String get sectionWhoCanJoin => 'Wer mitmachen kann';

  @override
  String get planTypePrivate => 'Privat';

  @override
  String get planTypeOpen => 'Offen';

  @override
  String get planTypeGuided => 'Geführt';

  @override
  String get planTypePrivateHint =>
      'Alle in der Gruppe sagen Ja zu jeder neuen Person.';

  @override
  String get planTypeOpenHint =>
      'Alle können sofort mitmachen, ohne auf ein Ja zu warten.';

  @override
  String get planTypeGuidedHint =>
      'Du führst, und die Kletternden bezahlen dich. Nur du beantwortest Anfragen.';

  @override
  String get pricePerClimber => 'Preis pro Person';

  @override
  String get priceInvalid =>
      'Gib einen Preis über 0 mit höchstens zwei Nachkommastellen ein';

  @override
  String get currency => 'Währung';

  @override
  String guidedPrice(String price) {
    return 'Geführt · $price';
  }

  @override
  String get paidToGuide => 'Wird an die Führung bezahlt, nicht über Grigri.';

  @override
  String get theGuideDecides => 'Die Führung entscheidet';

  @override
  String get openJoinAtOnce => 'Offen: sofort dabei';

  @override
  String get signInBadge => '100 % kostenlos';

  @override
  String get signInHeadline => 'Schließ dich einem Kletterplan an.';

  @override
  String get signInFreeLine => 'Kostenlos für alle: keine Karte, kein Abo.';

  @override
  String get signInStampJoin => 'DABEI';

  @override
  String get signInDeckWhen => 'Diesen Samstag · Sport · 6b–7a';

  @override
  String get signInDeckWho => 'Mara, Jonas und 1 weitere Person';

  @override
  String get signInHowTitle => 'So funktioniert’s';

  @override
  String get signInStep1Title => 'Mach einen Plan';

  @override
  String get signInStep1Body =>
      'Wo, wann und welche Grade: ein Gebiet, ein Samstag, 6a bis 7a.';

  @override
  String get signInStep2Title => 'Wisch nach rechts';

  @override
  String get signInStep2Body =>
      'Dir gefällt ein Plan? Wisch nach rechts. Die Gruppe nimmt Neue einzeln auf, wenn alle Ja sagen.';

  @override
  String get signInStep3Title => 'Klettert zusammen';

  @override
  String get signInStep3Body =>
      'Jedes Match öffnet den Gruppenchat des Plans: Seil, Mitfahrt und Kaffee klären.';

  @override
  String get signInFreeTitle => 'Kostenlos. Wirklich.';

  @override
  String get signInFree1 => 'Pläne und Wischen';

  @override
  String get signInFree2 => 'Matches und Gruppenchats';

  @override
  String get signInFree3 => 'Fotos der Gebiete';

  @override
  String get signInFree4 => 'Keine Karte zur Anmeldung';

  @override
  String get signInFreePremium =>
      'Premium ist freiwillig: nur zum Werben auf Grigri und für den Routenfinder. Klettern mit Grigri kostet nichts.';

  @override
  String get signInFinalTitle =>
      'Der Kletterplan fürs Wochenende ist nur einen Wisch entfernt.';

  @override
  String get signInJoinFree => 'Kostenlos mit Google beitreten';

  @override
  String signInPhotoBy(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String get signInDeckWhen2 => 'Sonntag · Mehrseillänge · 6a–6b';

  @override
  String get signInDeckWho2 => 'Iker und Lea';

  @override
  String get signInDeckWhen3 => 'Nächstes Wochenende · Bouldern · 6C–7A';

  @override
  String get signInDeckWho3 => 'Noor, Tomás und 2 weitere';

  @override
  String get privacyPolicy => 'Datenschutzerklärung';

  @override
  String get support => 'Support';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get deleteAccountQuestion => 'Dein Konto löschen?';

  @override
  String get deleteAccountMessage =>
      'Löscht dein Grigri-Konto endgültig: dein Profil und deine Fotos, deine Nachrichten und Fotos in Gruppenchats, deine Anfragen und deine Anzeigen. Du verlässt alle deine Pläne: Pläne, die du organisierst, übernimmt jemand anderes aus dem Plan, und ein Plan, in dem nur du bist, endet. Premium, hier per Karte bezahlt, wird sofort gekündigt, ohne Erstattung der restlichen Zeit. Ein über Apple gekauftes Abo musst du in den Einstellungen deines iPhones kündigen. Du wirst auf allen Geräten abgemeldet.';

  @override
  String get deleteAccountUnderstand =>
      'Ich verstehe, dass das nicht rückgängig zu machen ist';

  @override
  String get deleteAccountConfirm => 'Endgültig löschen';

  @override
  String get errorDeleteAccount =>
      'Dein Konto konnte nicht gelöscht werden. Versuch es noch einmal.';

  @override
  String get moreActions => 'Mehr';

  @override
  String get report => 'Melden';

  @override
  String blockPerson(String name) {
    return '$name blockieren';
  }

  @override
  String get reportTitle => 'Warum meldest du das?';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Belästigung';

  @override
  String get reportReasonInappropriate => 'Unangemessene Inhalte';

  @override
  String get reportReasonFake => 'Falsches Profil';

  @override
  String get reportReasonOther => 'Sonstiges';

  @override
  String get reportDetailsHint =>
      'Sonst noch etwas, das wir wissen sollten? (optional)';

  @override
  String get reportSend => 'Meldung senden';

  @override
  String get reportThanks => 'Danke, wir prüfen es innerhalb von 24 Stunden.';

  @override
  String get blockPersonMessage =>
      'Ihr seht eure Pläne gegenseitig nicht mehr, keiner kann bei einem Plan des anderen anfragen, seine Anfragen zu deinen Plänen werden abgelehnt und du siehst seine Nachrichten nicht. Die Person erfährt es nicht.';

  @override
  String blockedPersonDone(String name) {
    return '$name ist blockiert.';
  }

  @override
  String get blockedPeopleTitle => 'Blockierte Personen';

  @override
  String get blockedPeopleEmpty => 'Du hast niemanden blockiert.';

  @override
  String get adminReportsTab => 'Meldungen';

  @override
  String get adminReportsEmpty => 'Keine Meldungen zu prüfen.';

  @override
  String reportedBy(String name) {
    return 'Gemeldet von $name';
  }

  @override
  String get reportKindProfile => 'Profil';

  @override
  String get reportKindPlan => 'Plan';

  @override
  String get reportKindMessage => 'Chatnachricht';

  @override
  String get reportKindPic => 'Planfoto';

  @override
  String get reportKindAd => 'Anzeige';

  @override
  String get reportDismiss => 'Verwerfen';

  @override
  String get reportRemove => 'Inhalt entfernen';

  @override
  String get reportBlock => 'Kletterer sperren';

  @override
  String get noticeReportsTitle => 'Neue Meldungen zu prüfen';

  @override
  String get noticeReportsBody =>
      'Admin → Meldungen · innerhalb von 24 Stunden beantworten';

  @override
  String get errorObjectionable =>
      'Bitte bleib freundlich: Der Text enthält Wörter, die Grigri nicht erlaubt.';

  @override
  String get adRegionsTitle => 'Wo sie erscheint';

  @override
  String get adRegionsEverywhere =>
      'Überall. Füge ein Land, eine Region oder einen Ort hinzu, um sie nur Kletternden dort zu zeigen.';

  @override
  String get adRegionsHelp =>
      'Für Kletternde, die an diesen Orten sind oder in der Nähe klettern.';

  @override
  String get adAddRegion => 'Region hinzufügen';

  @override
  String adRemoveRegion(String name) {
    return '$name entfernen';
  }

  @override
  String get adRegionSearchLabel => 'Land, Region oder Ort';

  @override
  String get adRegionSearchHelp =>
      'Zum Beispiel Spanien, Katalonien oder Siurana. Die Anzeige reicht auch etwas darüber hinaus.';

  @override
  String adShowsIn(String places) {
    return 'Erscheint in $places';
  }

  @override
  String get adShowsEverywhere => 'Erscheint überall';
}
