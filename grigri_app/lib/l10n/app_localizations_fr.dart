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
  String get tabDiscover => 'Découvrir';

  @override
  String get tabPlans => 'Plans';

  @override
  String get tabChats => 'Discussions';

  @override
  String get tabNotifications => 'Notifications';

  @override
  String get tabProfile => 'Profil';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'Le plan';

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
  String get createProfile => 'Crée ton profil';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get removePhoto => 'Supprimer la photo';

  @override
  String get photoFailed => 'Impossible d\'obtenir cette photo';

  @override
  String get welcomeIntro =>
      'Bienvenue sur Grigri ! Dis aux grimpeurs qui tu es et ce que tu grimpes : ils le verront quand tu demanderas à rejoindre leurs plans.';

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
  String get startClimbing => 'Commencer à grimper';

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
  String distanceKm(int km) {
    String _temp0 = intl.Intl.pluralLogic(
      km,
      locale: localeName,
      other: 'À $km km de toi',
      zero: 'À moins de 1 km de toi',
    );
    return '$_temp0';
  }

  @override
  String get setWhereYouClimbHint =>
      'Indique où tu grimpes pour voir d\'abord les plans près de toi.';

  @override
  String get setAction => 'Indiquer';

  @override
  String get discoverTitle => 'Découvrir des plans';

  @override
  String askedToJoinPending(String organizer) {
    return 'Demande envoyée : en attente. $organizer décidera ; tu recevras une notification.';
  }

  @override
  String askedToJoinPendingGroup(String organizer) {
    return 'Demande envoyée : en attente. $organizer et le groupe décideront ; tu recevras une notification.';
  }

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
  String get organizedBy => 'Organisé par';

  @override
  String get alsoInGroup => 'Aussi dans le groupe';

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
  String get notificationsTitle => 'Notifications';

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
  String get leavePlan => 'Quitter le plan';

  @override
  String get cancelPlanQuestion => 'Annuler le plan ?';

  @override
  String get leavePlanQuestion => 'Quitter le plan ?';

  @override
  String get cancelPlanMessage => 'Le plan et sa discussion disparaîtront.';

  @override
  String leaveOrganizerMessage(String name) {
    return '$name l\'organisera.';
  }

  @override
  String get leaveMessage => 'Tu ne pourras plus le rejoindre.';

  @override
  String get stay => 'Rester';

  @override
  String get leave => 'Quitter';

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
  String get adminTitle => 'Admin : demandes';

  @override
  String get noOpenRequestsTitle => 'Aucune demande en cours';

  @override
  String get noOpenRequestsMessage =>
      'Quand quelqu\'un demande à rejoindre un plan, sa demande apparaît ici pour que tu l\'approuves ou la rejettes.';

  @override
  String get aPlan => 'un plan';

  @override
  String askedAt(String day, String time) {
    return 'Demandé le $day, $time';
  }

  @override
  String get reject => 'Rejeter';

  @override
  String get approve => 'Approuver';

  @override
  String rejectNameQuestion(String name) {
    return 'Rejeter $name ?';
  }

  @override
  String rejectMessage(String plan) {
    return 'Cette personne ne rejoindra pas $plan, et on lui dira que le groupe a refusé.';
  }

  @override
  String approveNameQuestion(String name) {
    return 'Approuver $name ?';
  }

  @override
  String approveMessage(String plan) {
    return 'Cette personne rejoint $plan maintenant, comme si tout le groupe avait dit oui.';
  }

  @override
  String adminJoined(String name, String plan) {
    return '$name a rejoint $plan.';
  }

  @override
  String get roles => 'Rôles';

  @override
  String get rolesSignedOut =>
      'Non connecté : tes rôles apparaîtront ici une fois connecté.';

  @override
  String get rolesFailed => 'Impossible de récupérer tes rôles depuis rbacr.';

  @override
  String get noRoles => 'Pas encore de rôle dans Grigri.';

  @override
  String rolesAs(String email) {
    return 'En tant que $email';
  }
}
