// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get disciplineSport => 'Sport';

  @override
  String get disciplineTrad => 'Trad';

  @override
  String get disciplineBouldering => 'Bouldering';

  @override
  String get disciplineGym => 'Gym';

  @override
  String get gradeSystemEuropean => 'European';

  @override
  String get gradeSystemAmerican => 'American';

  @override
  String get gearRope => 'Rope';

  @override
  String get gearQuickdraws => 'Quickdraws';

  @override
  String get gearRack => 'Trad rack';

  @override
  String get gearCrashPad => 'Crash pad';

  @override
  String get gearCar => 'Car';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get more => 'More';

  @override
  String get refresh => 'Refresh';

  @override
  String get signOut => 'Sign out';

  @override
  String get tryAgain => 'Try again';

  @override
  String get retry => 'Retry';

  @override
  String get newPlan => 'New plan';

  @override
  String get you => 'You';

  @override
  String get youLower => 'you';

  @override
  String get someone => 'Someone';

  @override
  String climberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count climbers',
      one: '1 climber',
    );
    return '$_temp0';
  }

  @override
  String saidYesCount(int yes, int total) {
    return '$yes of $total said yes';
  }

  @override
  String get declined => 'Declined';

  @override
  String get pending => 'Pending';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String errorStatus(int status) {
    return 'Something went wrong ($status).';
  }

  @override
  String get errorTimeout => 'The server took too long to answer.';

  @override
  String get errorUnreachable => 'Couldn\'t reach the server.';

  @override
  String get errorPhotoTimeout => 'The photo upload took too long.';

  @override
  String get errorPhotoUnreachable => 'Couldn\'t upload the photo.';

  @override
  String errorPhotoStatus(int status) {
    return 'The photo upload failed ($status).';
  }

  @override
  String get errorPhotoType => 'Use a JPEG, PNG or WebP photo.';

  @override
  String get errorSignedOut => 'Signed out: please sign in again.';

  @override
  String get errorSignIn => 'Couldn\'t sign in with Google. Try again.';

  @override
  String get errorSession => 'Couldn\'t sign in. Try again.';

  @override
  String get errorSignOutEverywhere =>
      'Couldn\'t sign out everywhere. Try again.';

  @override
  String get loadFailedTitle => 'Couldn\'t load your profile';

  @override
  String get signInTagline =>
      'Find climbing partners: make a plan, or swipe right on one, and climb together.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get tabDiscover => 'Find';

  @override
  String get tabPlans => 'Plans';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabNotifications => 'Alerts';

  @override
  String get tabProfile => 'Me';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'The plan';

  @override
  String get demoTag => 'Demo';

  @override
  String get demoNotice => 'Demo: made-up people and plans.';

  @override
  String get yourGrades => 'Your grades';

  @override
  String get profileClimbs => 'Climbs';

  @override
  String get profileGear => 'Gear';

  @override
  String gearPhotoOf(String name, int number) {
    return '$name\'s gear, photo $number';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get profileTitle => 'Profile';

  @override
  String get signOutQuestion => 'Sign out?';

  @override
  String get signOutMessage =>
      'Your profile, plans and chats stay saved; sign back in to see them.';

  @override
  String get signOutEverywhere => 'Sign out everywhere';

  @override
  String get signOutEverywhereQuestion => 'Sign out everywhere?';

  @override
  String get signOutEverywhereMessage =>
      'Signs you out on every phone and browser you signed in on, this one too. Your profile, plans and chats stay saved.';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get profileFootnote =>
      'Your profile is about you: what you climb and the gear you have. When and where are for plans, made separately in Plans.';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get photoFailed => 'Couldn\'t get that photo';

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get changePhoto => 'Change your photo';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameRequired => 'Your name, please';

  @override
  String get ageLabel => 'Age (optional)';

  @override
  String ageRange(int min, int max) {
    return '$min to $max';
  }

  @override
  String get bioLabel => 'About you';

  @override
  String get whatYouClimb => 'What you climb';

  @override
  String get whatYouClimbHint =>
      'Pick your disciplines and the grades you climb.';

  @override
  String get gearYouCanBring => 'Gear you can bring';

  @override
  String get gearHint => 'Add photos of it, too.';

  @override
  String gearPhoto(int number) {
    return 'Gear photo $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Remove gear photo $number';
  }

  @override
  String get addGearPhoto => 'Add a gear photo';

  @override
  String get whereYouClimb => 'Where you climb';

  @override
  String get whereYouClimbHint =>
      'Plans near here come first on Discover. Only you see it.';

  @override
  String get setYourLocation => 'Set your location';

  @override
  String get yourLocation => 'Your location';

  @override
  String get clearYourLocation => 'Clear your location';

  @override
  String removeArea(String name) {
    return 'Remove $name';
  }

  @override
  String get addArea => 'Add an area';

  @override
  String get locationSearchLabel => 'A crag or gym near there';

  @override
  String get search => 'Search';

  @override
  String get locationPrivacy => 'Kept to about 1 km, and only you see it.';

  @override
  String placesAttribution(String attribution) {
    return 'Places: $attribution';
  }

  @override
  String get loadingPlaces => 'Loading places…';

  @override
  String get noPlacesFound => 'No places found';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get locationNotFound =>
      'Couldn\'t tell where you are. Search for a place instead.';

  @override
  String nearPlace(String place) {
    return 'Near $place';
  }

  @override
  String get currentLocation => 'Where I am';

  @override
  String get setWhereYouClimbHint =>
      'Set where you climb to see plans near you first.';

  @override
  String get setAction => 'Set';

  @override
  String get discoverTitle => 'Discover plans';

  @override
  String get askedToJoinSent =>
      'Asked to join. You\'ll get an alert when you\'re accepted.';

  @override
  String get noPlansToJoinTitle => 'No plans to join right now';

  @override
  String get noPlansToJoinMessage =>
      'Nobody has a plan open for you yet. Make your own: climbers who fit will ask to join.';

  @override
  String get swipeJoin => 'Join';

  @override
  String get swipePass => 'Pass';

  @override
  String get pass => 'Pass';

  @override
  String get askToJoin => 'Ask to join';

  @override
  String get sharePlan => 'Share this plan';

  @override
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  ) {
    return 'Climbing plan on Grigri: $discipline at $place, $when. $link';
  }

  @override
  String get organizedBy => 'Organized by';

  @override
  String get alsoInGroup => 'Also in the group';

  @override
  String get showGroup => 'Show the group';

  @override
  String get hideGroup => 'Hide the group';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get noChatsTitle => 'No chats yet';

  @override
  String get noChatsMessage =>
      'Every plan you\'re in has a group chat. Make a plan, or ask to join one, and its chat opens here.';

  @override
  String get findPlan => 'Find a plan';

  @override
  String messagePreview(String author, String text) {
    return '$author: $text';
  }

  @override
  String toAnswer(int count) {
    return '$count to answer';
  }

  @override
  String get notInGroupTitle => 'Not in this group';

  @override
  String get notInGroupMessage => 'You left this plan, so its chat is closed.';

  @override
  String get messageHint => 'Message the group';

  @override
  String get send => 'Send';

  @override
  String get wantsToJoinYourAnswer => 'Wants to join · your answer';

  @override
  String declineName(String name) {
    return 'Decline $name';
  }

  @override
  String acceptName(String name) {
    return 'Accept $name';
  }

  @override
  String askedToJoinAt(String time) {
    return 'Asked to join · $time';
  }

  @override
  String noGradesYet(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'No sport grades yet',
      'trad': 'No trad grades yet',
      'bouldering': 'No bouldering grades yet',
      'gym': 'No gym grades yet',
      'other': 'No grades yet',
    });
    return '$_temp0';
  }

  @override
  String get joined => 'Joined';

  @override
  String get closed => 'Closed';

  @override
  String namesSaidYes(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names said yes',
      one: '$names said yes',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'waiting for $names';
  }

  @override
  String get itsAMatch => 'It\'s a match!';

  @override
  String get matchEveryoneSaidYes =>
      'Everyone in the group said yes. You\'re climbing together:';

  @override
  String matchJoinsGroup(String name) {
    return '$name joins the group:';
  }

  @override
  String get openGroupChat => 'Open the group chat';

  @override
  String get keepSwiping => 'Keep swiping';

  @override
  String get notificationsTitle => 'Alerts';

  @override
  String get nothingYetTitle => 'Nothing yet';

  @override
  String get nothingYetMessage =>
      'When someone asks to join a plan you\'re in, or a group answers your request, you\'ll hear about it here.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name wants to join';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · answer in the group chat';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'You\'re in: $plan';
  }

  @override
  String get noticeAcceptedBody =>
      'The group accepted you. Say hi in the chat.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Not this time: $plan';
  }

  @override
  String get noticeDeclinedBody => 'The group declined your request.';

  @override
  String get newTag => 'New';

  @override
  String get planGoneTitle => 'Plan gone';

  @override
  String get planGoneMessage =>
      'Everyone left this plan, or it\'s no longer open.';

  @override
  String get yourPlan => 'Your plan';

  @override
  String get planTitle => 'Plan';

  @override
  String get edit => 'Edit';

  @override
  String get declinedGroupSaidNo => 'Declined: the group said no';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'Pending: $yes of $total said yes';
  }

  @override
  String theGroupCount(int count) {
    return 'The group · $count';
  }

  @override
  String get organizer => 'Organizer';

  @override
  String get member => 'Member';

  @override
  String get askingToJoin => 'Asking to join';

  @override
  String get youSaidYes => 'You said yes';

  @override
  String get answerInChat => 'Answer in the chat';

  @override
  String get groupChat => 'Group chat';

  @override
  String get cancelPlan => 'Cancel the plan';

  @override
  String get cancelPlanQuestion => 'Cancel the plan?';

  @override
  String get cancelPlanMessage => 'It and its chat will be gone.';

  @override
  String get cancelPlanOthersMessage =>
      'It leaves your plans and chats; the others keep it. You can\'t rejoin it later.';

  @override
  String get cancelPlanOrganizerMessage =>
      'It leaves your plans and chats; the others keep it, and one of them, picked at random, will organize it. You can\'t rejoin it later.';

  @override
  String get keepPlan => 'Keep it';

  @override
  String get confirmCancelPlan => 'Cancel it';

  @override
  String get editPlan => 'Edit plan';

  @override
  String get pickFutureTime => 'Pick a time that\'s still to come.';

  @override
  String get sectorLabel => 'Sector, crag or gym';

  @override
  String get sectorHint => 'Search, or type it in';

  @override
  String sectorsAttribution(String attribution) {
    return 'Sectors: $attribution';
  }

  @override
  String get whereRequired => 'Where are you climbing?';

  @override
  String get sectionDiscipline => 'Climbing';

  @override
  String get sectionWhere => 'Where';

  @override
  String get sectionWhen => 'When';

  @override
  String get sectionGrades => 'Grades';

  @override
  String get sectionNotes => 'Notes';

  @override
  String get notesHint =>
      'Meeting point, car seats, the routes you have in mind…';

  @override
  String get publishPlan => 'Publish the plan';

  @override
  String get yourPlans => 'Your plans';

  @override
  String get noPlansYetTitle => 'No plans yet';

  @override
  String get noPlansYetMessage =>
      'Make a plan (what, where, when) and climbers who fit will ask to join. Or swipe right on one in Discover.';

  @override
  String get plansClimbing => 'Climbing';

  @override
  String get plansAskedToJoin => 'Asked to join';

  @override
  String get organizing => 'Organizing';

  @override
  String get accepted => 'Accepted';

  @override
  String toReview(int count) {
    return '$count to review';
  }

  @override
  String get groupSaidNo => 'The group said no';

  @override
  String waitingForNames(String names) {
    return 'Waiting for $names';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String get adminTitle => 'Admin: join requests';

  @override
  String get noOpenRequestsTitle => 'No open requests';

  @override
  String get noOpenRequestsMessage =>
      'When anyone asks to join a plan, their request shows up here for you to approve or reject.';

  @override
  String get aPlan => 'a plan';

  @override
  String askedAt(String day, String time) {
    return 'Asked $day, $time';
  }

  @override
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String rejectNameQuestion(String name) {
    return 'Reject $name?';
  }

  @override
  String rejectMessage(String plan) {
    return 'They won\'t join $plan, and they\'ll be told the group declined.';
  }

  @override
  String approveNameQuestion(String name) {
    return 'Approve $name?';
  }

  @override
  String approveMessage(String plan) {
    return 'They join $plan now, as if everyone in the group had said yes.';
  }

  @override
  String adminJoined(String name, String plan) {
    return '$name joined $plan.';
  }

  @override
  String get roles => 'Roles';

  @override
  String get rolesFailed => 'Couldn\'t get your roles from rbacr.';

  @override
  String get noRoles => 'No roles in Grigri yet.';

  @override
  String get nudge => 'Nudge';

  @override
  String get nudged => 'Nudged';

  @override
  String get nudgeTooltip => 'Remind the group to answer (once every 12 hours)';

  @override
  String nudgeSent(String names) {
    return 'Nudge sent to $names';
  }

  @override
  String noticeNudgeTitle(String name) {
    return '$name is waiting for your answer';
  }

  @override
  String noticeNudgeBody(String plan) {
    return 'To join $plan · accept or decline in the group chat';
  }

  @override
  String get attachMedia => 'Add a photo or video';

  @override
  String get recordVideo => 'Record a video';

  @override
  String get chooseVideo => 'Choose a video';

  @override
  String get photoMessage => 'Photo';

  @override
  String get videoMessage => 'Video';

  @override
  String get removeAttachment => 'Remove the attachment';

  @override
  String get uploadingMedia => 'Uploading…';

  @override
  String get playVideo => 'Play the video';

  @override
  String get videoUnavailable => 'This video can\'t be played.';

  @override
  String get mediaUnavailable => 'Not available';

  @override
  String get errorMediaType =>
      'Use a JPEG, PNG or WebP photo, or an MP4 or MOV video.';

  @override
  String errorVideoTooBig(int mb) {
    return 'Videos can be at most $mb MB: send a shorter one.';
  }

  @override
  String matchScore(int percent, String level) {
    return 'Match $percent% · $level';
  }

  @override
  String get matchLevelLongShot => 'long shot';

  @override
  String get matchLevelPossible => 'possible';

  @override
  String get matchLevelGood => 'good';

  @override
  String get matchLevelGreat => 'great';

  @override
  String get matchReasonOtherDiscipline => 'You don\'t climb this discipline';

  @override
  String get matchReasonTooHard => 'Its grades are well above yours';

  @override
  String get matchReasonTooEasy => 'Its grades are well below yours';

  @override
  String get matchReasonStartsSoon => 'Starts in less than 12 hours';

  @override
  String get matchReasonFar => 'More than 100 km away';

  @override
  String get matchReasonBigGroup => 'Five or more people must all say yes';

  @override
  String get matchReasonCrowded => 'Ten or more others are waiting';

  @override
  String get matchReasonInGradesNearby => 'In your grades and nearby';

  @override
  String get matchReasonInGrades => 'In your grades';

  @override
  String get matchReasonCloseGrades => 'Within a grade or two of yours';

  @override
  String get adminScoresTitle => 'Match scores';

  @override
  String get adminScoresNone =>
      'No scoring run yet. scripts/score-matches.sh scores every profile against every upcoming plan.';

  @override
  String adminScoresRun(
    String day,
    String time,
    int scored,
    int pairs,
    int climbers,
    int plans,
  ) {
    return 'Last run $day, $time: $scored of $pairs pairs, $climbers people × $plans plans';
  }

  @override
  String adminScoresProblems(int failed, int skipped) {
    return '$failed failed, $skipped over the run\'s cap';
  }

  @override
  String get adminScoresEmpty => 'The last run scored no pairs.';
}
