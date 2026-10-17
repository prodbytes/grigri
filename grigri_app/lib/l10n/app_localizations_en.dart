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
  String get gearBelayDevice => 'Belay device';

  @override
  String get gearHarness => 'Harness';

  @override
  String get gearHelmet => 'Helmet';

  @override
  String get gearShoes => 'Climbing shoes';

  @override
  String get yourGear => 'Your gear';

  @override
  String get editGear => 'Edit gear';

  @override
  String get addGear => 'Add your gear';

  @override
  String get gearEmpty =>
      'Add the gear you own, with photos: your plans\' groups see it, and check they have what they need.';

  @override
  String get gearShared => 'For the group';

  @override
  String get gearSharedHint => 'The group shares these: a rope does for two.';

  @override
  String get gearPersonal => 'Your own';

  @override
  String get gearPersonalHint => 'Every climber needs their own.';

  @override
  String get gearPhotos => 'Photos';

  @override
  String get planGearAllSet => 'The group has all it needs.';

  @override
  String planGearMissing(String items) {
    return 'Some gear is missing: $items';
  }

  @override
  String get planGearGym => 'The gym has ropes and mats, and rents the rest.';

  @override
  String get planGearGuided =>
      'The guide brings the group\'s gear: check you have your own.';

  @override
  String get noGearListed => 'No gear listed';

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
  String get errorSignInApple => 'Couldn\'t sign in with Apple. Try again.';

  @override
  String get errorSession => 'Couldn\'t sign in. Try again.';

  @override
  String get errorSignOutEverywhere =>
      'Couldn\'t sign out everywhere. Try again.';

  @override
  String get loadFailedTitle => 'Couldn\'t load your profile';

  @override
  String get signInTagline =>
      'Make a plan, or swipe right on one, and climb together.';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithApple => 'Sign in with Apple';

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
  String get gradeSystem => 'Grade system';

  @override
  String get gradeSystemHint =>
      'How grades are written across the app, here for a route and a boulder.';

  @override
  String get whatYouClimb => 'What you climb';

  @override
  String get whatYouClimbHint =>
      'Pick your disciplines and the grades you climb.';

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
  String get dateToBeDecided => 'Date to be decided';

  @override
  String dayAndMoreDays(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$day +$_temp0';
  }

  @override
  String get addDay => 'Add a day';

  @override
  String get leaveDateOpen => 'Leave the date open';

  @override
  String get whenHelp =>
      'The date is optional. Add more days for a longer trip.';

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
  String get adminTitle => 'Admin: people';

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
  String get adminNoClimbersTitle => 'Nobody yet';

  @override
  String get adminNoClimbersMessage =>
      'Everyone with a profile shows up here, to block or unblock.';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String get blocked => 'Blocked';

  @override
  String blockNameQuestion(String name) {
    return 'Block $name?';
  }

  @override
  String get blockMessage =>
      'They can\'t use Grigri until you unblock them, and their plans leave everyone\'s Discover.';

  @override
  String get blockedTitle => 'Your account is blocked';

  @override
  String get blockedMessage =>
      'An admin blocked your account, so you can\'t use Grigri for now.';

  @override
  String get yourPics => 'Your Pics';

  @override
  String get grigriPics => 'GriGri Pics';

  @override
  String get yourPicsEmpty =>
      'No photos yet. Add one, or send one in the chat.';

  @override
  String get grigriPicsEmpty => 'No GriGri Pics of this place yet.';

  @override
  String get addPlanPic => 'Add a photo to the plan';

  @override
  String get deletePic => 'Delete photo';

  @override
  String get deletePicQuestion => 'Delete this photo?';

  @override
  String get deletePicMessage => 'It leaves the plan\'s photos for everyone.';

  @override
  String get deleteChatPicMessage =>
      'It leaves the plan\'s photos; the chat keeps it.';

  @override
  String get delete => 'Delete';

  @override
  String picCredit(String author, String license) {
    return 'Photo: $author, $license';
  }

  @override
  String picAddedBy(String name) {
    return 'Added by $name';
  }

  @override
  String picFromChat(String name) {
    return 'Sent in the chat by $name';
  }

  @override
  String get premiumTitle => 'Grigri Premium';

  @override
  String get premiumPitch =>
      'Advertise on Grigri: your ads show between plans on everyone\'s Discover. Everything else stays the same.';

  @override
  String premiumMonthly(String price) {
    return '$price a month';
  }

  @override
  String premiumYearly(String price) {
    return '$price a year';
  }

  @override
  String get premiumCheckoutHint =>
      'You pay on Stripe\'s secure page, in your browser. Come back here when you\'re done.';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium: renews on $date';
  }

  @override
  String premiumEndsOn(String date) {
    return 'Premium: ends on $date';
  }

  @override
  String get premiumManage => 'Manage subscription';

  @override
  String get premiumUnavailable => 'Premium isn\'t available yet.';

  @override
  String get premiumCheckRefresh => 'I\'ve paid: check again';

  @override
  String get premiumRestore => 'Restore purchases';

  @override
  String premiumAppStoreTerms(String prices) {
    return 'Grigri Premium is an auto-renewing subscription: $prices. Payment is charged to your Apple ID when you confirm. It renews automatically unless you cancel at least 24 hours before the end of the period. Manage or cancel it in your App Store account settings.';
  }

  @override
  String get premiumPrivacyPolicy => 'Privacy policy';

  @override
  String get premiumTermsOfUse => 'Terms of use (EULA)';

  @override
  String get premiumStoreUnavailable =>
      'The App Store can\'t be reached right now.';

  @override
  String get premiumNothingToRestore => 'No App Store subscription to restore.';

  @override
  String get premiumPurchaseFailed => 'The purchase didn\'t go through.';

  @override
  String get errorOpenLink => 'Couldn\'t open the link.';

  @override
  String get tabAds => 'Ads';

  @override
  String get adTag => 'Ad';

  @override
  String adBy(String name) {
    return 'Ad by $name';
  }

  @override
  String get swipeOpen => 'Open';

  @override
  String get swipeSkip => 'Skip';

  @override
  String get openAd => 'Open the ad\'s link';

  @override
  String get skipAd => 'Skip the ad';

  @override
  String get shareAd => 'Share the ad\'s link';

  @override
  String get adsTitle => 'Your ads';

  @override
  String get adsEmptyTitle => 'No ads yet';

  @override
  String get adsEmptyMessage =>
      'Add an ad: once an admin approves it, it shows between plans on everyone\'s Discover.';

  @override
  String get newAd => 'New ad';

  @override
  String get adStatusPending => 'Waiting for review';

  @override
  String get adStatusApproved => 'Approved: showing';

  @override
  String get adStatusRejected => 'Rejected';

  @override
  String get deleteAdQuestion => 'Delete this ad?';

  @override
  String get deleteAdMessage => 'It leaves Discover for good.';

  @override
  String get adTextLabel => 'Text over the ad';

  @override
  String get adLinkLabel => 'Link (https://…)';

  @override
  String get adLinkInvalid => 'Enter a web address, starting with https://';

  @override
  String get adAddMedia => 'Add a photo or video';

  @override
  String get adRemoveMedia => 'Remove the photo or video';

  @override
  String get adVideoPicked => 'Video';

  @override
  String get adNeedsContent => 'Add text, a photo or a video.';

  @override
  String get adSubmit => 'Send for review';

  @override
  String get adSent => 'Sent: an admin will review it.';

  @override
  String get adPreview => 'Preview';

  @override
  String get adsNeedPremium =>
      'Your Premium has ended: your ads don\'t show. Renew it in your profile.';

  @override
  String get adminUsersTab => 'Users';

  @override
  String get adminAdsTab => 'Ads';

  @override
  String get adminAdsTitle => 'Admin';

  @override
  String get adsOnDiscover => 'On Discover';

  @override
  String get adEveryOff => 'No ads';

  @override
  String adEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'An ad after every $count plans',
      one: 'An ad after every plan',
    );
    return '$_temp0';
  }

  @override
  String get adApprove => 'Approve';

  @override
  String get adReject => 'Reject';

  @override
  String get adminAdsEmpty => 'No ads here';

  @override
  String get routeFinder => 'Routes on the rock';

  @override
  String get routeFinderLoading => 'Getting the walls here ready…';

  @override
  String get routeFinderNoWalls =>
      'No walls known here yet. Record the first route.';

  @override
  String routeFinderSeen(String wall, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count routes',
      one: '1 route',
      zero: 'no routes yet',
    );
    return '$wall: $_temp0';
  }

  @override
  String get routeFinderPoint => 'Point the camera at the wall';

  @override
  String get routeFinderSnap => 'Take a photo of the wall to find its routes';

  @override
  String get cameraUnavailable => 'The camera isn\'t available.';

  @override
  String get recordRoute => 'Record a route';

  @override
  String get teachView => 'Learn this view';

  @override
  String get findRoutes => 'Find routes';

  @override
  String get learnedView => 'Thanks! Grigri knows this wall better now.';

  @override
  String get needTwoBolts => 'Tap at least two bolts.';

  @override
  String get routeSaved => 'Route saved.';

  @override
  String get undoBolt => 'Undo the last bolt';

  @override
  String get tapBolts => 'Tap each bolt, from the ground up to the anchor';

  @override
  String get tapBoltsNewWall =>
      'New rock: tap each bolt, from the ground up. This photo will teach Grigri the wall.';

  @override
  String get notRecognized => 'Grigri didn\'t recognize this wall.';

  @override
  String get saveRoute => 'Save the route';

  @override
  String get newWallNote =>
      'A new wall: this photo will teach Grigri what it looks like.';

  @override
  String get wallName => 'Wall';

  @override
  String get routeName => 'Route name';

  @override
  String get routeScale => 'Route';

  @override
  String get boulderScale => 'Boulder';

  @override
  String get routeGrade => 'Grade';

  @override
  String kmAway(String km) {
    return '$km km';
  }

  @override
  String get sectionWhoCanJoin => 'Who can join';

  @override
  String get planTypePrivate => 'Private';

  @override
  String get planTypeOpen => 'Open';

  @override
  String get planTypeGuided => 'Guided';

  @override
  String get planTypePrivateHint =>
      'Everyone in the group says yes to each newcomer.';

  @override
  String get planTypeOpenHint =>
      'Anyone can join at once, without waiting for a yes.';

  @override
  String get planTypeGuidedHint =>
      'You guide, and climbers pay you. Only you answer requests to join.';

  @override
  String get pricePerClimber => 'Price per climber';

  @override
  String get priceInvalid => 'Enter a price above 0, with at most two decimals';

  @override
  String get currency => 'Currency';

  @override
  String guidedPrice(String price) {
    return 'Guided · $price';
  }

  @override
  String get paidToGuide => 'Paid to the guide, not through Grigri.';

  @override
  String get theGuideDecides => 'The guide decides';

  @override
  String get openJoinAtOnce => 'Open: join at once';

  @override
  String get signInBadge => '100% free';

  @override
  String get signInHeadline => 'Join a climbing plan.';

  @override
  String get signInFreeLine =>
      'Free for every climber: no card, no subscription.';

  @override
  String get signInStampJoin => 'JOIN';

  @override
  String get signInDeckWhen => 'This Saturday · Sport · 6b–7a';

  @override
  String get signInDeckWho => 'Mara, Jonas and 1 more';

  @override
  String get signInHowTitle => 'How it works';

  @override
  String get signInStep1Title => 'Make a plan';

  @override
  String get signInStep1Body =>
      'Where, when and which grades: a crag, a Saturday, 6a to 7a.';

  @override
  String get signInStep2Title => 'Swipe right';

  @override
  String get signInStep2Body =>
      'Like someone\'s plan? Swipe right. The group lets newcomers in one at a time, when everyone says yes.';

  @override
  String get signInStep3Title => 'Climb together';

  @override
  String get signInStep3Body =>
      'Every match opens the plan\'s group chat: sort out the rope, the ride and the coffee.';

  @override
  String get signInFreeTitle => 'Free. Really.';

  @override
  String get signInFree1 => 'Plans and swiping';

  @override
  String get signInFree2 => 'Matches and group chats';

  @override
  String get signInFree3 => 'Crag photos';

  @override
  String get signInFree4 => 'No card to sign up';

  @override
  String get signInFreePremium =>
      'Premium is optional: it\'s only for advertising on Grigri and for the route finder. Climbing with Grigri costs nothing.';

  @override
  String get signInFinalTitle =>
      'This weekend\'s climbing plan is one swipe away.';

  @override
  String get signInJoinFree => 'Join free with Google';

  @override
  String signInPhotoBy(String author, String license) {
    return 'Photo: $author, $license';
  }

  @override
  String get signInDeckWhen2 => 'Sunday · Multi-pitch · 6a–6b';

  @override
  String get signInDeckWho2 => 'Iker and Lea';

  @override
  String get signInDeckWhen3 => 'Next weekend · Bouldering · 6C–7A';

  @override
  String get signInDeckWho3 => 'Noor, Tomás and 2 more';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get support => 'Support';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountQuestion => 'Delete your account?';

  @override
  String get deleteAccountMessage =>
      'This deletes your Grigri account for good: your profile and photos, your messages and photos in group chats, your join requests and your ads. You leave all your plans: someone else in a plan you organize takes it over, and a plan with only you in it ends. Premium paid with a card here is cancelled at once, with no refund of the time left. A subscription bought through Apple must be cancelled in your iPhone\'s Settings. You\'re signed out on every device.';

  @override
  String get deleteAccountUnderstand => 'I understand this can\'t be undone';

  @override
  String get deleteAccountConfirm => 'Delete for good';

  @override
  String get errorDeleteAccount => 'Couldn\'t delete your account. Try again.';

  @override
  String get moreActions => 'More';

  @override
  String get report => 'Report';

  @override
  String blockPerson(String name) {
    return 'Block $name';
  }

  @override
  String get reportTitle => 'Why are you reporting this?';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonFake => 'Fake profile';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDetailsHint => 'Anything else we should know? (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportThanks => 'Thanks, we\'ll review it within 24 hours.';

  @override
  String get blockPersonMessage =>
      'You won\'t see each other\'s plans, neither of you can ask to join a plan the other is in, their requests to your plans are declined, and you won\'t see their messages. They aren\'t told.';

  @override
  String blockedPersonDone(String name) {
    return '$name is blocked.';
  }

  @override
  String get blockedPeopleTitle => 'Blocked people';

  @override
  String get blockedPeopleEmpty => 'You haven\'t blocked anyone.';

  @override
  String get adminReportsTab => 'Reports';

  @override
  String get adminReportsEmpty => 'No reports to review.';

  @override
  String reportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get reportKindProfile => 'Profile';

  @override
  String get reportKindPlan => 'Plan';

  @override
  String get reportKindMessage => 'Chat message';

  @override
  String get reportKindPic => 'Plan photo';

  @override
  String get reportKindAd => 'Ad';

  @override
  String get reportDismiss => 'Dismiss';

  @override
  String get reportRemove => 'Remove content';

  @override
  String get reportBlock => 'Block climber';

  @override
  String get noticeReportsTitle => 'New reports to review';

  @override
  String get noticeReportsBody => 'Admin → Reports · answer within 24 hours';

  @override
  String get errorObjectionable =>
      'Please keep it friendly: that has words Grigri doesn\'t allow.';

  @override
  String get areaGuide => 'Area guide';

  @override
  String get guideAccess => 'Access';

  @override
  String get guideClimbing => 'Type of climbing';

  @override
  String get guideRock => 'Rock';

  @override
  String get guideRoutes => 'Routes';

  @override
  String get guideSeason => 'Season';

  @override
  String get guideTips => 'Tips and advice';

  @override
  String get guideReading => 'Further reading';

  @override
  String get guideSectors => 'Sectors';

  @override
  String get guideClimbs => 'Featured routes';

  @override
  String get guideClosures => 'Closures';

  @override
  String get guideClosedNow => 'Closed now';

  @override
  String get guideAreas => 'Climbing areas';

  @override
  String get guideAdvice => 'Before you climb';

  @override
  String get guideServices => 'Services';

  @override
  String get guideLinks => 'Useful links';

  @override
  String get guideBibliography => 'Bibliography';

  @override
  String get guideOpenAll => 'The whole guide';

  @override
  String guideSource(String title, String publisher, int year) {
    return 'From “$title”, $publisher, $year.';
  }

  @override
  String guideCredits(String text, String photos) {
    return 'Text: $text · Photos: $photos';
  }

  @override
  String guideClosure(String sector, String from, String to, String reason) {
    return '$sector: closed $from – $to ($reason)';
  }

  @override
  String get guideAccessMap => 'Access map';

  @override
  String get adRegionsTitle => 'Where it shows';

  @override
  String get adRegionsEverywhere =>
      'Everywhere. Add a country, region or town to show it only to climbers there.';

  @override
  String get adRegionsHelp =>
      'To climbers who are in these places, or climb near them.';

  @override
  String get adAddRegion => 'Add a region';

  @override
  String adRemoveRegion(String name) {
    return 'Remove $name';
  }

  @override
  String get adRegionSearchLabel => 'Country, region or town';

  @override
  String get adRegionSearchHelp =>
      'For example Spain, Catalonia or Siurana. The ad also reaches a little around it.';

  @override
  String adShowsIn(String places) {
    return 'Shows in $places';
  }

  @override
  String get adShowsEverywhere => 'Shows everywhere';
}
