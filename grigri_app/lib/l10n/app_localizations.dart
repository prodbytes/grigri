import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ca'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// Discipline: sport climbing (bolted routes).
  ///
  /// In en, this message translates to:
  /// **'Sport'**
  String get disciplineSport;

  /// Discipline: traditional climbing, placing your own protection.
  ///
  /// In en, this message translates to:
  /// **'Trad'**
  String get disciplineTrad;

  /// Discipline: bouldering.
  ///
  /// In en, this message translates to:
  /// **'Bouldering'**
  String get disciplineBouldering;

  /// Discipline: climbing in an indoor gym.
  ///
  /// In en, this message translates to:
  /// **'Gym'**
  String get disciplineGym;

  /// Grade system toggle: French grades for routes, Fontainebleau for boulders.
  ///
  /// In en, this message translates to:
  /// **'European'**
  String get gradeSystemEuropean;

  /// Grade system toggle: YDS for routes, the V scale for boulders.
  ///
  /// In en, this message translates to:
  /// **'American'**
  String get gradeSystemAmerican;

  /// Gear someone can bring: a climbing rope.
  ///
  /// In en, this message translates to:
  /// **'Rope'**
  String get gearRope;

  /// Gear someone can bring: quickdraws.
  ///
  /// In en, this message translates to:
  /// **'Quickdraws'**
  String get gearQuickdraws;

  /// Gear someone can bring: a trad rack (cams and nuts).
  ///
  /// In en, this message translates to:
  /// **'Trad rack'**
  String get gearRack;

  /// Gear someone can bring: a bouldering crash pad.
  ///
  /// In en, this message translates to:
  /// **'Crash pad'**
  String get gearCrashPad;

  /// Gear someone can bring: a car, for a lift.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get gearCar;

  /// Button: save the form.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Dialog button: dismiss without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Tooltip of the overflow (three dots) menu.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Tooltip of the refresh button.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Menu item and button: sign out of the app.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Button: try loading again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Small button: retry a failed request.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Button and screen title: create a new climbing plan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// Stands for the user in lists of people ("You, Marta"), capitalized.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// Stands for the user in a lowercase list of first names ("marta, you").
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get youLower;

  /// Name shown for a climber the app does not know yet.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// How many climbers are in a plan.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 climber} other{{count} climbers}}'**
  String climberCount(int count);

  /// How many members of the group accepted a join request.
  ///
  /// In en, this message translates to:
  /// **'{yes} of {total} said yes'**
  String saidYesCount(int yes, int total);

  /// Status tag: the join request was turned down.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// Status tag: the join request waits for the group.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Button: let the person join the plan.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Button: turn down the person asking to join.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// A day and a time, e.g. "Sat 17 Oct, 18:30".
  ///
  /// In en, this message translates to:
  /// **'{day}, {time}'**
  String dayAndTime(String day, String time);

  /// Shown when something failed without a reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorGeneric;

  /// The server failed without a message; status is the HTTP status code.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong ({status}).'**
  String errorStatus(int status);

  /// The server did not answer in time.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to answer.'**
  String get errorTimeout;

  /// No connection to the server.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server.'**
  String get errorUnreachable;

  /// A photo upload did not finish in time.
  ///
  /// In en, this message translates to:
  /// **'The photo upload took too long.'**
  String get errorPhotoTimeout;

  /// A photo upload could not connect.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the photo.'**
  String get errorPhotoUnreachable;

  /// A photo upload failed; status is the HTTP status code.
  ///
  /// In en, this message translates to:
  /// **'The photo upload failed ({status}).'**
  String errorPhotoStatus(int status);

  /// The picked photo is in a format the app cannot upload.
  ///
  /// In en, this message translates to:
  /// **'Use a JPEG, PNG or WebP photo.'**
  String get errorPhotoType;

  /// Snackbar: the session expired and the user was signed out.
  ///
  /// In en, this message translates to:
  /// **'Signed out: please sign in again.'**
  String get errorSignedOut;

  /// Google sign-in failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with Google. Try again.'**
  String get errorSignIn;

  /// The API would not start a session after signing in.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Try again.'**
  String get errorSession;

  /// Snackbar: signing out of every device failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign out everywhere. Try again.'**
  String get errorSignOutEverywhere;

  /// Title of the screen shown when the profile could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile'**
  String get loadFailedTitle;

  /// Sign-in screen, under the app name.
  ///
  /// In en, this message translates to:
  /// **'Find climbing partners: make a plan, or swipe right on one, and climb together.'**
  String get signInTagline;

  /// Button: sign in with a Google account.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// Bottom tab: the deck of plans to join.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get tabDiscover;

  /// Bottom tab: my plans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get tabPlans;

  /// Bottom tab: group chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// Bottom tab: notifications.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get tabNotifications;

  /// Bottom tab: my profile.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get tabProfile;

  /// Bottom tab for admins.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get tabAdmin;

  /// Heading of the highlighted plan card (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'The plan'**
  String get thePlan;

  /// Badge: the plan is at grades the user climbs.
  ///
  /// In en, this message translates to:
  /// **'Your grades'**
  String get yourGrades;

  /// Profile section heading: disciplines and grades (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Climbs'**
  String get profileClimbs;

  /// Profile section heading: gear (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get profileGear;

  /// Accessibility label of a photo of someone's gear.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s gear, photo {number}'**
  String gearPhotoOf(String name, int number);

  /// Label of the app language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language picker option: follow the device's language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// Title of the Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Title of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutQuestion;

  /// Body of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Your profile, plans and chats stay saved; sign back in to see them.'**
  String get signOutMessage;

  /// Menu item and button: end the sessions on every phone and browser.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere'**
  String get signOutEverywhere;

  /// Title of the sign-out-everywhere confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere?'**
  String get signOutEverywhereQuestion;

  /// Body of the sign-out-everywhere confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Signs you out on every phone and browser you signed in on, this one too. Your profile, plans and chats stay saved.'**
  String get signOutEverywhereMessage;

  /// Button and screen title: edit my profile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// Note under my profile.
  ///
  /// In en, this message translates to:
  /// **'Your profile is about you: what you climb and the gear you have. When and where are for plans, made separately in Plans.'**
  String get profileFootnote;

  /// Photo source option: the camera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takePhoto;

  /// Photo source option: the photo library.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// Option: remove my profile photo.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// Snackbar: the picked photo could not be read.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get that photo'**
  String get photoFailed;

  /// Tooltip of my avatar when it has no photo.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get addPhoto;

  /// Tooltip of my avatar when it has a photo.
  ///
  /// In en, this message translates to:
  /// **'Change your photo'**
  String get changePhoto;

  /// Label of the name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Error when the name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Your name, please'**
  String get nameRequired;

  /// Label of the optional age field.
  ///
  /// In en, this message translates to:
  /// **'Age (optional)'**
  String get ageLabel;

  /// Error when the age is out of range.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max}'**
  String ageRange(int min, int max);

  /// Label of the free-text field about the user.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get bioLabel;

  /// Profile editor section heading (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'What you climb'**
  String get whatYouClimb;

  /// Hint under the "What you climb" heading.
  ///
  /// In en, this message translates to:
  /// **'Pick your disciplines and the grades you climb.'**
  String get whatYouClimbHint;

  /// Profile editor section heading (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Gear you can bring'**
  String get gearYouCanBring;

  /// Hint under the gear heading.
  ///
  /// In en, this message translates to:
  /// **'Add photos of it, too.'**
  String get gearHint;

  /// Accessibility label of one of my gear photos.
  ///
  /// In en, this message translates to:
  /// **'Gear photo {number}'**
  String gearPhoto(int number);

  /// Tooltip: remove one of my gear photos.
  ///
  /// In en, this message translates to:
  /// **'Remove gear photo {number}'**
  String removeGearPhoto(int number);

  /// Tooltip: add a gear photo.
  ///
  /// In en, this message translates to:
  /// **'Add a gear photo'**
  String get addGearPhoto;

  /// Profile editor section heading: my location and areas (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Where you climb'**
  String get whereYouClimb;

  /// Hint under the "Where you climb" heading.
  ///
  /// In en, this message translates to:
  /// **'Plans near here come first on Discover. Only you see it.'**
  String get whereYouClimbHint;

  /// Location row when no location is set.
  ///
  /// In en, this message translates to:
  /// **'Set your location'**
  String get setYourLocation;

  /// Subtitle of the location row, and title of the location picker.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get yourLocation;

  /// Tooltip: clear my location.
  ///
  /// In en, this message translates to:
  /// **'Clear your location'**
  String get clearYourLocation;

  /// Tooltip: remove one of my areas of interest.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeArea(String name);

  /// Button and picker title: add an area where I like to climb.
  ///
  /// In en, this message translates to:
  /// **'Add an area'**
  String get addArea;

  /// Label of the location picker search field.
  ///
  /// In en, this message translates to:
  /// **'A crag or gym near there'**
  String get locationSearchLabel;

  /// Hint of a search field.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Helper under the location search: the location is rounded and private.
  ///
  /// In en, this message translates to:
  /// **'Kept to about 1 km, and only you see it.'**
  String get locationPrivacy;

  /// Credit for the place data, under the location search.
  ///
  /// In en, this message translates to:
  /// **'Places: {attribution}'**
  String placesAttribution(String attribution);

  /// The place index is still loading.
  ///
  /// In en, this message translates to:
  /// **'Loading places…'**
  String get loadingPlaces;

  /// The location search found nothing.
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get noPlacesFound;

  /// Location picker: take where the phone or browser is.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// The device could not tell where I am.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t tell where you are. Search for a place instead.'**
  String get locationNotFound;

  /// My location taken from the device, named after the nearest place in the index: "Near Siurana, Spain".
  ///
  /// In en, this message translates to:
  /// **'Near {place}'**
  String nearPlace(String place);

  /// My location taken from the device, when no place in the index is near it.
  ///
  /// In en, this message translates to:
  /// **'Where I am'**
  String get currentLocation;

  /// Discover hint when I have no location or areas.
  ///
  /// In en, this message translates to:
  /// **'Set where you climb to see plans near you first.'**
  String get setWhereYouClimbHint;

  /// Button next to the Discover hint: open the profile editor to set it.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get setAction;

  /// Title of the Discover tab.
  ///
  /// In en, this message translates to:
  /// **'Discover plans'**
  String get discoverTitle;

  /// Snackbar after asking to join a plan.
  ///
  /// In en, this message translates to:
  /// **'Asked to join. You\'ll get an alert when you\'re accepted.'**
  String get askedToJoinSent;

  /// Discover, empty: title.
  ///
  /// In en, this message translates to:
  /// **'No plans to join right now'**
  String get noPlansToJoinTitle;

  /// Discover, empty: message.
  ///
  /// In en, this message translates to:
  /// **'Nobody has a plan open for you yet. Make your own: climbers who fit will ask to join.'**
  String get noPlansToJoinMessage;

  /// Stamp on a card dragged right: ask to join (shown uppercased, keep it short).
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get swipeJoin;

  /// Stamp on a card dragged left: skip it (shown uppercased, keep it short).
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get swipePass;

  /// Tooltip of the button that skips a plan.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get pass;

  /// Tooltip of the button that asks to join a plan.
  ///
  /// In en, this message translates to:
  /// **'Ask to join'**
  String get askToJoin;

  /// Heading over the plan organizer (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Organized by'**
  String get organizedBy;

  /// Heading over the other members (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Also in the group'**
  String get alsoInGroup;

  /// Tooltip: show the others in the plan (the "+3" button on a card).
  ///
  /// In en, this message translates to:
  /// **'Show the group'**
  String get showGroup;

  /// Tooltip: hide the others in the plan again.
  ///
  /// In en, this message translates to:
  /// **'Hide the group'**
  String get hideGroup;

  /// Title of the Chats tab.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// Chats, empty: title.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsTitle;

  /// Chats, empty: message.
  ///
  /// In en, this message translates to:
  /// **'Every plan you\'re in has a group chat. Make a plan, or ask to join one, and its chat opens here.'**
  String get noChatsMessage;

  /// Button: go find a plan in Discover.
  ///
  /// In en, this message translates to:
  /// **'Find a plan'**
  String get findPlan;

  /// Last message in the chat list: author and text.
  ///
  /// In en, this message translates to:
  /// **'{author}: {text}'**
  String messagePreview(String author, String text);

  /// Badge: join requests waiting for my answer in a chat.
  ///
  /// In en, this message translates to:
  /// **'{count} to answer'**
  String toAnswer(int count);

  /// Chat of a plan I left: title.
  ///
  /// In en, this message translates to:
  /// **'Not in this group'**
  String get notInGroupTitle;

  /// Chat of a plan I left: message.
  ///
  /// In en, this message translates to:
  /// **'You left this plan, so its chat is closed.'**
  String get notInGroupMessage;

  /// Hint of the chat input.
  ///
  /// In en, this message translates to:
  /// **'Message the group'**
  String get messageHint;

  /// Tooltip of the send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Callout over someone asking to join who waits for my answer (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Wants to join · your answer'**
  String get wantsToJoinYourAnswer;

  /// Tooltip: decline this person.
  ///
  /// In en, this message translates to:
  /// **'Decline {name}'**
  String declineName(String name);

  /// Tooltip: accept this person.
  ///
  /// In en, this message translates to:
  /// **'Accept {name}'**
  String acceptName(String name);

  /// Header of a join request card in the chat (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Asked to join · {time}'**
  String askedToJoinAt(String time);

  /// Someone asking to join has no grades for the plan discipline.
  ///
  /// In en, this message translates to:
  /// **'{discipline, select, sport{No sport grades yet} trad{No trad grades yet} bouldering{No bouldering grades yet} gym{No gym grades yet} other{No grades yet}}'**
  String noGradesYet(String discipline);

  /// Status tag: the person joined the plan.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// Status tag: the request closed without the person joining.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// Who accepted a join request: a comma-separated list of first names.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{names} said yes} other{{names} said yes}}'**
  String namesSaidYes(String names, int count);

  /// Who has not answered a join request yet (lowercase, follows "… said yes ·").
  ///
  /// In en, this message translates to:
  /// **'waiting for {names}'**
  String waitingFor(String names);

  /// Big title when someone joins a plan.
  ///
  /// In en, this message translates to:
  /// **'It\'s a match!'**
  String get itsAMatch;

  /// Match screen, when I joined.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the group said yes. You\'re climbing together:'**
  String get matchEveryoneSaidYes;

  /// Match screen, when someone else joined.
  ///
  /// In en, this message translates to:
  /// **'{name} joins the group:'**
  String matchJoinsGroup(String name);

  /// Button: open the group chat.
  ///
  /// In en, this message translates to:
  /// **'Open the group chat'**
  String get openGroupChat;

  /// Button: close the match screen.
  ///
  /// In en, this message translates to:
  /// **'Keep swiping'**
  String get keepSwiping;

  /// Title of the Notifications tab.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get notificationsTitle;

  /// Notifications, empty: title.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get nothingYetTitle;

  /// Notifications, empty: message.
  ///
  /// In en, this message translates to:
  /// **'When someone asks to join a plan you\'re in, or a group answers your request, you\'ll hear about it here.'**
  String get nothingYetMessage;

  /// Notification title: someone asked to join my plan.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to join'**
  String noticeWantsToJoin(String name);

  /// Notification body for a join request.
  ///
  /// In en, this message translates to:
  /// **'{plan} · answer in the group chat'**
  String noticeAnswerInChat(String plan);

  /// Notification title: a group accepted me.
  ///
  /// In en, this message translates to:
  /// **'You\'re in: {plan}'**
  String noticeYoureIn(String plan);

  /// Notification body: a group accepted me.
  ///
  /// In en, this message translates to:
  /// **'The group accepted you. Say hi in the chat.'**
  String get noticeAcceptedBody;

  /// Notification title: a group declined me.
  ///
  /// In en, this message translates to:
  /// **'Not this time: {plan}'**
  String noticeNotThisTime(String plan);

  /// Notification body: a group declined me.
  ///
  /// In en, this message translates to:
  /// **'The group declined your request.'**
  String get noticeDeclinedBody;

  /// Tag on a notification I have not seen.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newTag;

  /// A plan that no longer exists: title.
  ///
  /// In en, this message translates to:
  /// **'Plan gone'**
  String get planGoneTitle;

  /// A plan that no longer exists: message.
  ///
  /// In en, this message translates to:
  /// **'Everyone left this plan, or it\'s no longer open.'**
  String get planGoneMessage;

  /// Title of a plan I organize.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get yourPlan;

  /// Title of a plan someone else organizes.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planTitle;

  /// Tooltip: edit the plan.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Tag on a plan whose group declined me.
  ///
  /// In en, this message translates to:
  /// **'Declined: the group said no'**
  String get declinedGroupSaidNo;

  /// Tag on a plan I asked to join.
  ///
  /// In en, this message translates to:
  /// **'Pending: {yes} of {total} said yes'**
  String pendingSaidYes(int yes, int total);

  /// Heading over the plan members (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'The group · {count}'**
  String theGroupCount(int count);

  /// Role of the member who organizes the plan.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get organizer;

  /// Role of the other members.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// Heading over people asking to join (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Asking to join'**
  String get askingToJoin;

  /// Tag: I accepted this request.
  ///
  /// In en, this message translates to:
  /// **'You said yes'**
  String get youSaidYes;

  /// Tag: answer this request in the chat.
  ///
  /// In en, this message translates to:
  /// **'Answer in the chat'**
  String get answerInChat;

  /// Button: open the group chat.
  ///
  /// In en, this message translates to:
  /// **'Group chat'**
  String get groupChat;

  /// Button: cancel a plan I am alone in.
  ///
  /// In en, this message translates to:
  /// **'Cancel the plan'**
  String get cancelPlan;

  /// Button: leave the plan.
  ///
  /// In en, this message translates to:
  /// **'Leave the plan'**
  String get leavePlan;

  /// Dialog title: cancel the plan?
  ///
  /// In en, this message translates to:
  /// **'Cancel the plan?'**
  String get cancelPlanQuestion;

  /// Dialog title: leave the plan?
  ///
  /// In en, this message translates to:
  /// **'Leave the plan?'**
  String get leavePlanQuestion;

  /// Dialog body: what cancelling does.
  ///
  /// In en, this message translates to:
  /// **'It and its chat will be gone.'**
  String get cancelPlanMessage;

  /// Dialog body: the next member takes over as organizer.
  ///
  /// In en, this message translates to:
  /// **'{name} will organize it.'**
  String leaveOrganizerMessage(String name);

  /// Dialog body: leaving is final.
  ///
  /// In en, this message translates to:
  /// **'You can\'t rejoin it later.'**
  String get leaveMessage;

  /// Dialog button: do not leave.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// Dialog button: leave the plan.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// Title of the plan editor for an existing plan.
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get editPlan;

  /// Snackbar: the plan time is in the past.
  ///
  /// In en, this message translates to:
  /// **'Pick a time that\'s still to come.'**
  String get pickFutureTime;

  /// Label of the where field.
  ///
  /// In en, this message translates to:
  /// **'Sector, crag or gym'**
  String get sectorLabel;

  /// Hint of the where field.
  ///
  /// In en, this message translates to:
  /// **'Search, or type it in'**
  String get sectorHint;

  /// Credit for the sector data, under the where field.
  ///
  /// In en, this message translates to:
  /// **'Sectors: {attribution}'**
  String sectorsAttribution(String attribution);

  /// Error when the where field is empty.
  ///
  /// In en, this message translates to:
  /// **'Where are you climbing?'**
  String get whereRequired;

  /// Plan editor section: which discipline (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Climbing'**
  String get sectionDiscipline;

  /// Plan editor section (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get sectionWhere;

  /// Plan editor section (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get sectionWhen;

  /// Plan editor section (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get sectionGrades;

  /// Plan editor section (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sectionNotes;

  /// Hint of the plan notes field.
  ///
  /// In en, this message translates to:
  /// **'Meeting point, car seats, the routes you have in mind…'**
  String get notesHint;

  /// Button: create the plan.
  ///
  /// In en, this message translates to:
  /// **'Publish the plan'**
  String get publishPlan;

  /// Title of the Plans tab.
  ///
  /// In en, this message translates to:
  /// **'Your plans'**
  String get yourPlans;

  /// Plans, empty: title.
  ///
  /// In en, this message translates to:
  /// **'No plans yet'**
  String get noPlansYetTitle;

  /// Plans, empty: message.
  ///
  /// In en, this message translates to:
  /// **'Make a plan (what, where, when) and climbers who fit will ask to join. Or swipe right on one in Discover.'**
  String get noPlansYetMessage;

  /// Plans tab heading: plans I am in (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Climbing'**
  String get plansClimbing;

  /// Plans tab heading: plans I asked to join (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Asked to join'**
  String get plansAskedToJoin;

  /// Tag: I organize this plan.
  ///
  /// In en, this message translates to:
  /// **'Organizing'**
  String get organizing;

  /// Tag: I was accepted into this plan.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// Tag: join requests for me to review.
  ///
  /// In en, this message translates to:
  /// **'{count} to review'**
  String toReview(int count);

  /// The group declined my request.
  ///
  /// In en, this message translates to:
  /// **'The group said no'**
  String get groupSaidNo;

  /// Who my request still waits for (first names).
  ///
  /// In en, this message translates to:
  /// **'Waiting for {names}'**
  String waitingForNames(String names);

  /// Tooltip: remove a declined request from the list.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Title of the Admin tab.
  ///
  /// In en, this message translates to:
  /// **'Admin: join requests'**
  String get adminTitle;

  /// Admin, empty: title.
  ///
  /// In en, this message translates to:
  /// **'No open requests'**
  String get noOpenRequestsTitle;

  /// Admin, empty: message.
  ///
  /// In en, this message translates to:
  /// **'When anyone asks to join a plan, their request shows up here for you to approve or reject.'**
  String get noOpenRequestsMessage;

  /// Stands for a plan the admin cannot see the details of.
  ///
  /// In en, this message translates to:
  /// **'a plan'**
  String get aPlan;

  /// When someone asked to join.
  ///
  /// In en, this message translates to:
  /// **'Asked {day}, {time}'**
  String askedAt(String day, String time);

  /// Admin button: reject the request.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Admin button: approve the request.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// Admin dialog title.
  ///
  /// In en, this message translates to:
  /// **'Reject {name}?'**
  String rejectNameQuestion(String name);

  /// Admin dialog body.
  ///
  /// In en, this message translates to:
  /// **'They won\'t join {plan}, and they\'ll be told the group declined.'**
  String rejectMessage(String plan);

  /// Admin dialog title.
  ///
  /// In en, this message translates to:
  /// **'Approve {name}?'**
  String approveNameQuestion(String name);

  /// Admin dialog body.
  ///
  /// In en, this message translates to:
  /// **'They join {plan} now, as if everyone in the group had said yes.'**
  String approveMessage(String plan);

  /// Snackbar after an admin approves a request.
  ///
  /// In en, this message translates to:
  /// **'{name} joined {plan}.'**
  String adminJoined(String name, String plan);

  /// Heading of the roles card (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// Roles card when signed out.
  ///
  /// In en, this message translates to:
  /// **'Not signed in: your roles show here once you sign in.'**
  String get rolesSignedOut;

  /// Roles card when loading the roles failed. rbacr is the roles service: keep its name.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your roles from rbacr.'**
  String get rolesFailed;

  /// Roles card when the user has no roles.
  ///
  /// In en, this message translates to:
  /// **'No roles in Grigri yet.'**
  String get noRoles;

  /// Which account the roles belong to.
  ///
  /// In en, this message translates to:
  /// **'As {email}'**
  String rolesAs(String email);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ca',
    'de',
    'en',
    'es',
    'fr',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
