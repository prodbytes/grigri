// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get disciplineSport => 'Sportive';

  @override
  String get disciplineTrad => 'Trad';

  @override
  String get disciplineBouldering => 'Bloc';

  @override
  String get disciplineGym => 'Salle';

  @override
  String get gradeSystemEuropean => 'Européen';

  @override
  String get gradeSystemAmerican => 'Américain';

  @override
  String get gearRope => 'Corde';

  @override
  String get gearQuickdraws => 'Dégaines';

  @override
  String get gearRack => 'Coinceurs';

  @override
  String get gearCrashPad => 'Crash pad';

  @override
  String get gearCar => 'Voiture';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get more => 'Plus';

  @override
  String get refresh => 'Actualiser';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get retry => 'Réessayer';

  @override
  String get newPlan => 'Nouveau plan';

  @override
  String get you => 'Toi';

  @override
  String get youLower => 'toi';

  @override
  String get someone => 'Quelqu\'un';

  @override
  String climberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count grimpeurs',
      one: '1 grimpeur',
    );
    return '$_temp0';
  }

  @override
  String saidYesCount(int yes, int total) {
    return '$yes sur $total ont dit oui';
  }

  @override
  String get declined => 'Refusée';

  @override
  String get pending => 'En attente';

  @override
  String get accept => 'Accepter';

  @override
  String get decline => 'Refuser';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get errorGeneric => 'Une erreur s\'est produite.';

  @override
  String errorStatus(int status) {
    return 'Une erreur s\'est produite ($status).';
  }

  @override
  String get errorTimeout => 'Le serveur a mis trop de temps à répondre.';

  @override
  String get errorUnreachable => 'Impossible de joindre le serveur.';

  @override
  String get errorPhotoTimeout => 'L\'envoi de la photo a pris trop de temps.';

  @override
  String get errorPhotoUnreachable => 'Impossible d\'envoyer la photo.';

  @override
  String errorPhotoStatus(int status) {
    return 'L\'envoi de la photo a échoué ($status).';
  }

  @override
  String get errorPhotoType => 'Utilise une photo JPEG, PNG ou WebP.';

  @override
  String get errorSignedOut => 'Déconnecté : reconnecte-toi.';

  @override
  String get errorSignIn => 'Impossible de se connecter avec Google. Réessaie.';

  @override
  String get errorSession => 'Impossible de se connecter. Réessaie.';

  @override
  String get errorSignOutEverywhere =>
      'Impossible de se déconnecter partout. Réessaie.';

  @override
  String get loadFailedTitle => 'Impossible de charger ton profil';

  @override
  String get signInTagline =>
      'Trouve des partenaires d\'escalade : crée un plan ou swipe à droite sur un plan, et grimpez ensemble.';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get tabDiscover => 'Trouve';

  @override
  String get tabPlans => 'Plans';

  @override
  String get tabChats => 'Tchats';

  @override
  String get tabNotifications => 'Alertes';

  @override
  String get tabProfile => 'Moi';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'Le plan';

  @override
  String get demoTag => 'Démo';

  @override
  String get demoNotice => 'Démo : personnes et plans fictifs.';

  @override
  String get yourGrades => 'Ton niveau';

  @override
  String get profileClimbs => 'Grimpe';

  @override
  String get profileGear => 'Matériel';

  @override
  String gearPhotoOf(String name, int number) {
    return 'Matériel de $name, photo $number';
  }

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get profileTitle => 'Profil';

  @override
  String get signOutQuestion => 'Se déconnecter ?';

  @override
  String get signOutMessage =>
      'Ton profil, tes plans et tes discussions restent enregistrés ; reconnecte-toi pour les voir.';

  @override
  String get signOutEverywhere => 'Se déconnecter partout';

  @override
  String get signOutEverywhereQuestion => 'Se déconnecter partout ?';

  @override
  String get signOutEverywhereMessage =>
      'Te déconnecte de tous les téléphones et navigateurs où tu t\'es connecté, celui-ci compris. Ton profil, tes plans et tes discussions restent enregistrés.';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get profileFootnote =>
      'Ton profil parle de toi : ce que tu grimpes et le matériel que tu as. Le quand et le où sont pour les plans, créés à part dans Plans.';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get photoFailed => 'Impossible d\'obtenir cette photo';

  @override
  String get addPhoto => 'Ajouter une photo';

  @override
  String get changePhoto => 'Changer ta photo';

  @override
  String get nameLabel => 'Nom';

  @override
  String get nameRequired => 'Ton nom, s\'il te plaît';

  @override
  String get ageLabel => 'Âge (facultatif)';

  @override
  String ageRange(int min, int max) {
    return 'De $min à $max';
  }

  @override
  String get bioLabel => 'À propos de toi';

  @override
  String get whatYouClimb => 'Ce que tu grimpes';

  @override
  String get whatYouClimbHint =>
      'Choisis tes disciplines et les niveaux que tu grimpes.';

  @override
  String get gearYouCanBring => 'Matériel que tu peux apporter';

  @override
  String get gearHint => 'Ajoutes-en aussi des photos.';

  @override
  String gearPhoto(int number) {
    return 'Photo du matériel $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Supprimer la photo du matériel $number';
  }

  @override
  String get addGearPhoto => 'Ajouter une photo du matériel';

  @override
  String get whereYouClimb => 'Où tu grimpes';

  @override
  String get whereYouClimbHint =>
      'Les plans proches apparaissent en premier dans Découvrir. Toi seul le vois.';

  @override
  String get setYourLocation => 'Indique ta position';

  @override
  String get yourLocation => 'Ta position';

  @override
  String get clearYourLocation => 'Effacer ta position';

  @override
  String removeArea(String name) {
    return 'Retirer $name';
  }

  @override
  String get addArea => 'Ajouter un secteur';

  @override
  String get locationSearchLabel => 'Un site ou une salle près de là';

  @override
  String get search => 'Rechercher';

  @override
  String get locationPrivacy => 'Arrondie à 1 km environ, et toi seul la vois.';

  @override
  String placesAttribution(String attribution) {
    return 'Lieux : $attribution';
  }

  @override
  String get loadingPlaces => 'Chargement des lieux…';

  @override
  String get noPlacesFound => 'Aucun lieu trouvé';

  @override
  String get useCurrentLocation => 'Utiliser ma position actuelle';

  @override
  String get locationNotFound =>
      'Impossible de savoir où tu es. Cherche plutôt un lieu.';

  @override
  String nearPlace(String place) {
    return 'Près de $place';
  }

  @override
  String get currentLocation => 'Là où je suis';

  @override
  String get setWhereYouClimbHint =>
      'Indique où tu grimpes pour voir d\'abord les plans près de toi.';

  @override
  String get setAction => 'Indiquer';

  @override
  String get discoverTitle => 'Découvrir des plans';

  @override
  String get askedToJoinSent =>
      'Demande envoyée. Tu recevras une alerte dès qu\'on t\'accepte.';

  @override
  String get noPlansToJoinTitle => 'Aucun plan à rejoindre pour le moment';

  @override
  String get noPlansToJoinMessage =>
      'Personne n\'a encore de plan ouvert pour toi. Crée le tien : les grimpeurs qui correspondent demanderont à le rejoindre.';

  @override
  String get swipeJoin => 'Rejoindre';

  @override
  String get swipePass => 'Passer';

  @override
  String get pass => 'Passer';

  @override
  String get askToJoin => 'Demander à rejoindre';

  @override
  String get sharePlan => 'Partager ce plan';

  @override
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  ) {
    return 'Plan d\'escalade sur Grigri : $discipline à $place, $when. $link';
  }

  @override
  String get organizedBy => 'Organisé par';

  @override
  String get alsoInGroup => 'Aussi dans le groupe';

  @override
  String get showGroup => 'Voir le groupe';

  @override
  String get hideGroup => 'Masquer le groupe';

  @override
  String get chatsTitle => 'Discussions';

  @override
  String get noChatsTitle => 'Aucune discussion';

  @override
  String get noChatsMessage =>
      'Chaque plan dont tu fais partie a sa discussion de groupe. Crée un plan, ou demande à en rejoindre un, et sa discussion apparaîtra ici.';

  @override
  String get findPlan => 'Trouver un plan';

  @override
  String messagePreview(String author, String text) {
    return '$author : $text';
  }

  @override
  String toAnswer(int count) {
    return '$count à traiter';
  }

  @override
  String get notInGroupTitle => 'Tu n\'es pas dans ce groupe';

  @override
  String get notInGroupMessage =>
      'Tu as quitté ce plan, sa discussion est donc fermée.';

  @override
  String get messageHint => 'Écrire au groupe';

  @override
  String get send => 'Envoyer';

  @override
  String get wantsToJoinYourAnswer => 'Veut rejoindre · ta réponse';

  @override
  String declineName(String name) {
    return 'Refuser $name';
  }

  @override
  String acceptName(String name) {
    return 'Accepter $name';
  }

  @override
  String askedToJoinAt(String time) {
    return 'Demande · $time';
  }

  @override
  String noGradesYet(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Pas encore de niveau en sportive',
      'trad': 'Pas encore de niveau en trad',
      'bouldering': 'Pas encore de niveau en bloc',
      'gym': 'Pas encore de niveau en salle',
      'other': 'Pas encore de niveau',
    });
    return '$_temp0';
  }

  @override
  String get joined => 'A rejoint';

  @override
  String get closed => 'Fermée';

  @override
  String namesSaidYes(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ont dit oui : $names',
      one: 'A dit oui : $names',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'en attente de $names';
  }

  @override
  String get itsAMatch => 'C\'est un match !';

  @override
  String get matchEveryoneSaidYes =>
      'Tout le groupe a dit oui. Vous grimpez ensemble :';

  @override
  String matchJoinsGroup(String name) {
    return '$name rejoint le groupe :';
  }

  @override
  String get openGroupChat => 'Ouvrir la discussion du groupe';

  @override
  String get keepSwiping => 'Continuer à swiper';

  @override
  String get notificationsTitle => 'Alertes';

  @override
  String get nothingYetTitle => 'Rien pour l\'instant';

  @override
  String get nothingYetMessage =>
      'Quand quelqu\'un demande à rejoindre un de tes plans, ou qu\'un groupe répond à ta demande, tu le verras ici.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name veut rejoindre';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · réponds dans la discussion du groupe';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'Tu en es : $plan';
  }

  @override
  String get noticeAcceptedBody =>
      'Le groupe t\'a accepté. Dis bonjour dans la discussion.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Pas cette fois : $plan';
  }

  @override
  String get noticeDeclinedBody => 'Le groupe a refusé ta demande.';

  @override
  String get newTag => 'Nouveau';

  @override
  String get planGoneTitle => 'Plan disparu';

  @override
  String get planGoneMessage =>
      'Tout le monde a quitté ce plan, ou il n\'est plus ouvert.';

  @override
  String get yourPlan => 'Ton plan';

  @override
  String get planTitle => 'Plan';

  @override
  String get edit => 'Modifier';

  @override
  String get declinedGroupSaidNo => 'Refusée : le groupe a dit non';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'En attente : $yes sur $total ont dit oui';
  }

  @override
  String theGroupCount(int count) {
    return 'Le groupe · $count';
  }

  @override
  String get organizer => 'Organisateur';

  @override
  String get member => 'Membre';

  @override
  String get askingToJoin => 'Demandes';

  @override
  String get youSaidYes => 'Tu as dit oui';

  @override
  String get answerInChat => 'Réponds dans la discussion';

  @override
  String get groupChat => 'Discussion du groupe';

  @override
  String get cancelPlan => 'Annuler le plan';

  @override
  String get cancelPlanQuestion => 'Annuler le plan ?';

  @override
  String get cancelPlanMessage => 'Le plan et sa discussion disparaîtront.';

  @override
  String get cancelPlanOthersMessage =>
      'Il quittera tes plans et tes discussions ; les autres le gardent. Tu ne pourras plus le rejoindre.';

  @override
  String get cancelPlanOrganizerMessage =>
      'Il quittera tes plans et tes discussions ; les autres le gardent, et l\'un d\'eux, tiré au sort, l\'organisera. Tu ne pourras plus le rejoindre.';

  @override
  String get keepPlan => 'Le garder';

  @override
  String get confirmCancelPlan => 'L\'annuler';

  @override
  String get editPlan => 'Modifier le plan';

  @override
  String get pickFutureTime =>
      'Choisis une heure qui n\'est pas encore passée.';

  @override
  String get sectorLabel => 'Secteur, site ou salle';

  @override
  String get sectorHint => 'Cherche ou tape-le';

  @override
  String sectorsAttribution(String attribution) {
    return 'Secteurs : $attribution';
  }

  @override
  String get whereRequired => 'Où grimpes-tu ?';

  @override
  String get sectionDiscipline => 'Escalade';

  @override
  String get sectionWhere => 'Où';

  @override
  String get sectionWhen => 'Quand';

  @override
  String get sectionGrades => 'Niveaux';

  @override
  String get sectionNotes => 'Notes';

  @override
  String get notesHint =>
      'Point de rendez-vous, places en voiture, les voies que tu as en tête…';

  @override
  String get publishPlan => 'Publier le plan';

  @override
  String get yourPlans => 'Tes plans';

  @override
  String get noPlansYetTitle => 'Aucun plan pour le moment';

  @override
  String get noPlansYetMessage =>
      'Crée un plan (quoi, où, quand) et les grimpeurs qui correspondent demanderont à le rejoindre. Ou swipe à droite sur un plan dans Découvrir.';

  @override
  String get plansClimbing => 'Je grimpe';

  @override
  String get plansAskedToJoin => 'Demandés';

  @override
  String get organizing => 'J\'organise';

  @override
  String get accepted => 'Accepté';

  @override
  String toReview(int count) {
    return '$count à examiner';
  }

  @override
  String get groupSaidNo => 'Le groupe a dit non';

  @override
  String waitingForNames(String names) {
    return 'En attente de $names';
  }

  @override
  String get dismiss => 'Masquer';

  @override
  String get adminTitle => 'Admin : personnes';

  @override
  String get roles => 'Rôles';

  @override
  String get rolesFailed => 'Impossible de récupérer tes rôles depuis rbacr.';

  @override
  String get noRoles => 'Pas encore de rôle dans Grigri.';

  @override
  String get nudge => 'Relancer';

  @override
  String get nudged => 'Relancé';

  @override
  String get nudgeTooltip =>
      'Rappelle au groupe de répondre (une fois toutes les 12 heures)';

  @override
  String nudgeSent(String names) {
    return 'Relance envoyée à $names';
  }

  @override
  String noticeNudgeTitle(String name) {
    return '$name attend ta réponse';
  }

  @override
  String noticeNudgeBody(String plan) {
    return 'Pour rejoindre $plan · accepte ou refuse dans la discussion du groupe';
  }

  @override
  String get attachMedia => 'Ajouter une photo ou une vidéo';

  @override
  String get recordVideo => 'Filmer une vidéo';

  @override
  String get chooseVideo => 'Choisir une vidéo';

  @override
  String get photoMessage => 'Photo';

  @override
  String get videoMessage => 'Vidéo';

  @override
  String get removeAttachment => 'Retirer la pièce jointe';

  @override
  String get uploadingMedia => 'Envoi…';

  @override
  String get playVideo => 'Lire la vidéo';

  @override
  String get videoUnavailable => 'Impossible de lire cette vidéo.';

  @override
  String get mediaUnavailable => 'Indisponible';

  @override
  String get errorMediaType =>
      'Utilise une photo JPEG, PNG ou WebP, ou une vidéo MP4 ou MOV.';

  @override
  String errorVideoTooBig(int mb) {
    return 'Les vidéos font au plus $mb Mo : envoies-en une plus courte.';
  }

  @override
  String matchScore(int percent, String level) {
    return 'Affinité $percent% · $level';
  }

  @override
  String get matchLevelLongShot => 'peu probable';

  @override
  String get matchLevelPossible => 'possible';

  @override
  String get matchLevelGood => 'bonne';

  @override
  String get matchLevelGreat => 'excellente';

  @override
  String get matchReasonOtherDiscipline =>
      'Tu ne pratiques pas cette discipline';

  @override
  String get matchReasonTooHard =>
      'Ses cotations sont bien au-dessus des tiennes';

  @override
  String get matchReasonTooEasy =>
      'Ses cotations sont bien en dessous des tiennes';

  @override
  String get matchReasonStartsSoon => 'Commence dans moins de 12 heures';

  @override
  String get matchReasonFar => 'À plus de 100 km';

  @override
  String get matchReasonBigGroup =>
      'Cinq personnes ou plus doivent toutes dire oui';

  @override
  String get matchReasonCrowded => 'Dix autres ou plus attendent';

  @override
  String get matchReasonInGradesNearby => 'Dans tes cotations et tout près';

  @override
  String get matchReasonInGrades => 'Dans tes cotations';

  @override
  String get matchReasonCloseGrades => 'À une ou deux cotations des tiennes';

  @override
  String get adminNoClimbersTitle => 'Personne pour l\'instant';

  @override
  String get adminNoClimbersMessage =>
      'Toute personne ayant un profil apparaît ici, pour la bloquer ou la débloquer.';

  @override
  String get block => 'Bloquer';

  @override
  String get unblock => 'Débloquer';

  @override
  String get blocked => 'Bloqué';

  @override
  String blockNameQuestion(String name) {
    return 'Bloquer $name ?';
  }

  @override
  String get blockMessage =>
      'Cette personne ne pourra plus utiliser Grigri jusqu\'à ce que vous la débloquiez, et ses sorties disparaissent de Découvrir pour tous.';

  @override
  String get blockedTitle => 'Votre compte est bloqué';

  @override
  String get blockedMessage =>
      'Un administrateur a bloqué votre compte : vous ne pouvez pas utiliser Grigri pour l\'instant.';

  @override
  String get yourPics => 'Tes photos';

  @override
  String get grigriPics => 'GriGri Pics';

  @override
  String get yourPicsEmpty =>
      'Pas encore de photos. Ajoutes-en une, ou envoie-la dans le chat.';

  @override
  String get grigriPicsEmpty => 'Pas encore de GriGri Pics de cet endroit.';

  @override
  String get addPlanPic => 'Ajouter une photo au plan';

  @override
  String get deletePic => 'Supprimer la photo';

  @override
  String get deletePicQuestion => 'Supprimer cette photo ?';

  @override
  String get deletePicMessage =>
      'Elle quitte les photos du plan pour tout le monde.';

  @override
  String get deleteChatPicMessage =>
      'Elle quitte les photos du plan ; le chat la garde.';

  @override
  String get delete => 'Supprimer';

  @override
  String picCredit(String author, String license) {
    return 'Photo : $author, $license';
  }

  @override
  String picAddedBy(String name) {
    return 'Ajoutée par $name';
  }

  @override
  String picFromChat(String name) {
    return 'Envoyée dans le chat par $name';
  }

  @override
  String get routeFinder => 'Voies sur le rocher';

  @override
  String get routeFinderLoading => 'Préparation des parois d\'ici…';

  @override
  String get routeFinderNoWalls =>
      'Aucune paroi connue ici pour l\'instant. Enregistre la première voie.';

  @override
  String routeFinderSeen(String wall, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voies',
      one: '1 voie',
      zero: 'pas encore de voies',
    );
    return '$wall : $_temp0';
  }

  @override
  String get routeFinderPoint => 'Vise la paroi avec la caméra';

  @override
  String get routeFinderSnap =>
      'Prends la paroi en photo pour trouver ses voies';

  @override
  String get cameraUnavailable => 'La caméra n\'est pas disponible.';

  @override
  String get recordRoute => 'Enregistrer une voie';

  @override
  String get teachView => 'Apprendre cette vue';

  @override
  String get findRoutes => 'Trouver les voies';

  @override
  String get learnedView =>
      'Merci ! Grigri connaît mieux cette paroi maintenant.';

  @override
  String get needTwoBolts => 'Touche au moins deux points.';

  @override
  String get routeSaved => 'Voie enregistrée.';

  @override
  String get undoBolt => 'Annuler le dernier point';

  @override
  String get tapBolts => 'Touche chaque point, du sol au relais';

  @override
  String get tapBoltsNewWall =>
      'Rocher nouveau : touche chaque point, depuis le sol. Cette photo apprendra la paroi à Grigri.';

  @override
  String get notRecognized => 'Grigri n\'a pas reconnu cette paroi.';

  @override
  String get saveRoute => 'Enregistrer la voie';

  @override
  String get newWallNote =>
      'Une nouvelle paroi : cette photo apprendra à Grigri à la reconnaître.';

  @override
  String get wallName => 'Paroi';

  @override
  String get routeName => 'Nom de la voie';

  @override
  String get routeScale => 'Voie';

  @override
  String get boulderScale => 'Bloc';

  @override
  String get routeGrade => 'Cotation';
}
