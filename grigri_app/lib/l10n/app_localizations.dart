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

  /// Sign-in screen: under the headline.
  ///
  /// In en, this message translates to:
  /// **'Make a plan, or swipe right on one, and climb together.'**
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

  /// Tag next to a made-up (demo) person's name.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demoTag;

  /// Discreet line on a demo (automatically generated) plan or profile.
  ///
  /// In en, this message translates to:
  /// **'Demo: made-up people and plans.'**
  String get demoNotice;

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

  /// Tooltip of the small share button between ✕ and ✓ on Find.
  ///
  /// In en, this message translates to:
  /// **'Share this plan'**
  String get sharePlan;

  /// The text shared for a plan, with a link to the app.
  ///
  /// In en, this message translates to:
  /// **'Climbing plan on Grigri: {discipline} at {place}, {when}. {link}'**
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  );

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

  /// Button and menu item: cancel a plan I am in (others, if any, keep it).
  ///
  /// In en, this message translates to:
  /// **'Cancel the plan'**
  String get cancelPlan;

  /// Dialog title: cancel the plan?
  ///
  /// In en, this message translates to:
  /// **'Cancel the plan?'**
  String get cancelPlanQuestion;

  /// Dialog body: what cancelling does.
  ///
  /// In en, this message translates to:
  /// **'It and its chat will be gone.'**
  String get cancelPlanMessage;

  /// Dialog body: cancelling a plan others are in; they keep it.
  ///
  /// In en, this message translates to:
  /// **'It leaves your plans and chats; the others keep it. You can\'t rejoin it later.'**
  String get cancelPlanOthersMessage;

  /// Dialog body: the organizer cancelling a plan others are in; they keep it and a random one of them organizes it.
  ///
  /// In en, this message translates to:
  /// **'It leaves your plans and chats; the others keep it, and one of them, picked at random, will organize it. You can\'t rejoin it later.'**
  String get cancelPlanOrganizerMessage;

  /// Dialog button: do not cancel the plan.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get keepPlan;

  /// Dialog button: cancel the plan.
  ///
  /// In en, this message translates to:
  /// **'Cancel it'**
  String get confirmCancelPlan;

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

  /// A plan with no date yet, in place of its day.
  ///
  /// In en, this message translates to:
  /// **'Date to be decided'**
  String get dateToBeDecided;

  /// A plan of several days: its first day and how many more, e.g. "Sat 17 Oct +2 days".
  ///
  /// In en, this message translates to:
  /// **'{day} +{count, plural, =1{1 day} other{{count} days}}'**
  String dayAndMoreDays(String day, int count);

  /// Plan editor button: adds another day to the plan.
  ///
  /// In en, this message translates to:
  /// **'Add a day'**
  String get addDay;

  /// Plan editor tooltip: removes the plan's date, leaving it to be decided.
  ///
  /// In en, this message translates to:
  /// **'Leave the date open'**
  String get leaveDateOpen;

  /// Plan editor hint under the When section.
  ///
  /// In en, this message translates to:
  /// **'The date is optional. Add more days for a longer trip.'**
  String get whenHelp;

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
  /// **'Admin: people'**
  String get adminTitle;

  /// Heading of the roles card (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// Roles card: the API couldn't get my roles from rbacr (with Retry).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your roles from rbacr.'**
  String get rolesFailed;

  /// Roles card when the user has no roles.
  ///
  /// In en, this message translates to:
  /// **'No roles in Grigri yet.'**
  String get noRoles;

  /// Button on my pending join request: remind the members who have not answered.
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get nudge;

  /// Disabled button: I nudged the group less than 12 hours ago.
  ///
  /// In en, this message translates to:
  /// **'Nudged'**
  String get nudged;

  /// Tooltip of the Nudge button.
  ///
  /// In en, this message translates to:
  /// **'Remind the group to answer (once every 12 hours)'**
  String get nudgeTooltip;

  /// Snackbar after a nudge: who was reminded (first names).
  ///
  /// In en, this message translates to:
  /// **'Nudge sent to {names}'**
  String nudgeSent(String names);

  /// Notification title: someone asking to join my plan nudged me to answer.
  ///
  /// In en, this message translates to:
  /// **'{name} is waiting for your answer'**
  String noticeNudgeTitle(String name);

  /// Notification body for a nudge.
  ///
  /// In en, this message translates to:
  /// **'To join {plan} · accept or decline in the group chat'**
  String noticeNudgeBody(String plan);

  /// Tooltip of the chat button that adds a photo or video to a message.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or video'**
  String get attachMedia;

  /// Chat attach sheet: record a video with the camera.
  ///
  /// In en, this message translates to:
  /// **'Record a video'**
  String get recordVideo;

  /// Chat attach sheet: pick a video from the gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose a video'**
  String get chooseVideo;

  /// Chat list preview of a message that is only a photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoMessage;

  /// Chat list preview of a message that is only a video; label on a video in the chat.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoMessage;

  /// Tooltip: drop the photo or video picked for the next message.
  ///
  /// In en, this message translates to:
  /// **'Remove the attachment'**
  String get removeAttachment;

  /// Chat composer while a photo or video uploads.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploadingMedia;

  /// Tooltip/semantics of a video in the chat: opens the player.
  ///
  /// In en, this message translates to:
  /// **'Play the video'**
  String get playVideo;

  /// Video player: the video could not be loaded or played.
  ///
  /// In en, this message translates to:
  /// **'This video can\'t be played.'**
  String get videoUnavailable;

  /// A chat photo that could not be loaded (expired or offline).
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get mediaUnavailable;

  /// The picked chat attachment is in a format the app cannot send.
  ///
  /// In en, this message translates to:
  /// **'Use a JPEG, PNG or WebP photo, or an MP4 or MOV video.'**
  String get errorMediaType;

  /// The picked chat video is over the size limit; mb is the limit in megabytes.
  ///
  /// In en, this message translates to:
  /// **'Videos can be at most {mb} MB: send a shorter one.'**
  String errorVideoTooBig(int mb);

  /// Admins only: how likely a plan on the deck ends in a match.
  ///
  /// In en, this message translates to:
  /// **'Match {percent}% · {level}'**
  String matchScore(int percent, String level);

  /// A match score's level, lowest.
  ///
  /// In en, this message translates to:
  /// **'long shot'**
  String get matchLevelLongShot;

  /// A match score's level.
  ///
  /// In en, this message translates to:
  /// **'possible'**
  String get matchLevelPossible;

  /// A match score's level.
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get matchLevelGood;

  /// A match score's level, highest.
  ///
  /// In en, this message translates to:
  /// **'great'**
  String get matchLevelGreat;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'You don\'t climb this discipline'**
  String get matchReasonOtherDiscipline;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'Its grades are well above yours'**
  String get matchReasonTooHard;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'Its grades are well below yours'**
  String get matchReasonTooEasy;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'Starts in less than 12 hours'**
  String get matchReasonStartsSoon;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'More than 100 km away'**
  String get matchReasonFar;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'Five or more people must all say yes'**
  String get matchReasonBigGroup;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'Ten or more others are waiting'**
  String get matchReasonCrowded;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'In your grades and nearby'**
  String get matchReasonInGradesNearby;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'In your grades'**
  String get matchReasonInGrades;

  /// Why a match score is what it is.
  ///
  /// In en, this message translates to:
  /// **'Within a grade or two of yours'**
  String get matchReasonCloseGrades;

  /// Admin tab: nobody has a profile yet.
  ///
  /// In en, this message translates to:
  /// **'Nobody yet'**
  String get adminNoClimbersTitle;

  /// Admin tab: what shows up there.
  ///
  /// In en, this message translates to:
  /// **'Everyone with a profile shows up here, to block or unblock.'**
  String get adminNoClimbersMessage;

  /// Admin tab: block someone (they can't use Grigri).
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// Admin tab: unblock someone.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// Admin tab: under a blocked person's name.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// Confirms blocking someone.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockNameQuestion(String name);

  /// What blocking someone does.
  ///
  /// In en, this message translates to:
  /// **'They can\'t use Grigri until you unblock them, and their plans leave everyone\'s Discover.'**
  String get blockMessage;

  /// Shown to a blocked person instead of the app.
  ///
  /// In en, this message translates to:
  /// **'Your account is blocked'**
  String get blockedTitle;

  /// Why a blocked person can't use the app.
  ///
  /// In en, this message translates to:
  /// **'An admin blocked your account, so you can\'t use Grigri for now.'**
  String get blockedMessage;

  /// Plan screen: the section of photos members added to the plan, or sent in its chat.
  ///
  /// In en, this message translates to:
  /// **'Your Pics'**
  String get yourPics;

  /// Plan screen: the section of Grigri's own photos of the plan's crag (a name; keep as is).
  ///
  /// In en, this message translates to:
  /// **'GriGri Pics'**
  String get grigriPics;

  /// Plan screen: Your Pics has none yet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet. Add one, or send one in the chat.'**
  String get yourPicsEmpty;

  /// Plan screen: GriGri Pics has none of this place.
  ///
  /// In en, this message translates to:
  /// **'No GriGri Pics of this place yet.'**
  String get grigriPicsEmpty;

  /// Plan screen: the button that adds a photo to Your Pics.
  ///
  /// In en, this message translates to:
  /// **'Add a photo to the plan'**
  String get addPlanPic;

  /// Photo viewer: deletes a photo from Your Pics.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get deletePic;

  /// Confirmation title before deleting a plan photo.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get deletePicQuestion;

  /// Confirmation text: a photo added to the plan is deleted.
  ///
  /// In en, this message translates to:
  /// **'It leaves the plan\'s photos for everyone.'**
  String get deletePicMessage;

  /// Confirmation text: a chat photo leaves the plan's photos but stays in the chat.
  ///
  /// In en, this message translates to:
  /// **'It leaves the plan\'s photos; the chat keeps it.'**
  String get deleteChatPicMessage;

  /// Confirms deleting.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Under a GriGri Pics photo: who took it and its license, as the license asks.
  ///
  /// In en, this message translates to:
  /// **'Photo: {author}, {license}'**
  String picCredit(String author, String license);

  /// Under a Your Pics photo: who added it.
  ///
  /// In en, this message translates to:
  /// **'Added by {name}'**
  String picAddedBy(String name);

  /// Under a Your Pics photo that came from the chat: who sent it.
  ///
  /// In en, this message translates to:
  /// **'Sent in the chat by {name}'**
  String picFromChat(String name);

  /// Profile card heading: the Premium subscription.
  ///
  /// In en, this message translates to:
  /// **'Grigri Premium'**
  String get premiumTitle;

  /// Profile card: what Premium is for (advertising only).
  ///
  /// In en, this message translates to:
  /// **'Advertise on Grigri: your ads show between plans on everyone\'s Discover. Everything else stays the same.'**
  String get premiumPitch;

  /// Button: subscribe monthly, with the price ("$20").
  ///
  /// In en, this message translates to:
  /// **'{price} a month'**
  String premiumMonthly(String price);

  /// Button: subscribe yearly, with the price ("$200").
  ///
  /// In en, this message translates to:
  /// **'{price} a year'**
  String premiumYearly(String price);

  /// Under the subscribe buttons: payment happens on Stripe's page.
  ///
  /// In en, this message translates to:
  /// **'You pay on Stripe\'s secure page, in your browser. Come back here when you\'re done.'**
  String get premiumCheckoutHint;

  /// Profile card when subscribed: renews on this date.
  ///
  /// In en, this message translates to:
  /// **'Premium: renews on {date}'**
  String premiumActiveUntil(String date);

  /// Profile card when cancelled: Premium ends on this date.
  ///
  /// In en, this message translates to:
  /// **'Premium: ends on {date}'**
  String premiumEndsOn(String date);

  /// Button: open Stripe's billing portal.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get premiumManage;

  /// Profile card when Premium can't be bought yet (no payments set up).
  ///
  /// In en, this message translates to:
  /// **'Premium isn\'t available yet.'**
  String get premiumUnavailable;

  /// Button: check again whether Premium is active (after paying).
  ///
  /// In en, this message translates to:
  /// **'I\'ve paid: check again'**
  String get premiumCheckRefresh;

  /// Error: the browser couldn't be opened for a link.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get errorOpenLink;

  /// Bottom navigation tab: my ads (Premium). One short word.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get tabAds;

  /// Tag on an ad's card on the deck.
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get adTag;

  /// On an ad's card: who placed it.
  ///
  /// In en, this message translates to:
  /// **'Ad by {name}'**
  String adBy(String name);

  /// Stamp while dragging an ad right: opens its link (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get swipeOpen;

  /// Stamp while dragging an ad left (shown uppercased).
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get swipeSkip;

  /// Tooltip of ✓ when the top card is an ad.
  ///
  /// In en, this message translates to:
  /// **'Open the ad\'s link'**
  String get openAd;

  /// Tooltip of ✕ when the top card is an ad.
  ///
  /// In en, this message translates to:
  /// **'Skip the ad'**
  String get skipAd;

  /// Tooltip of the share button when the top card is an ad.
  ///
  /// In en, this message translates to:
  /// **'Share the ad\'s link'**
  String get shareAd;

  /// Ads tab title.
  ///
  /// In en, this message translates to:
  /// **'Your ads'**
  String get adsTitle;

  /// Ads tab with no ads yet.
  ///
  /// In en, this message translates to:
  /// **'No ads yet'**
  String get adsEmptyTitle;

  /// Ads tab with no ads yet: what an ad does.
  ///
  /// In en, this message translates to:
  /// **'Add an ad: once an admin approves it, it shows between plans on everyone\'s Discover.'**
  String get adsEmptyMessage;

  /// Button and editor title: a new ad.
  ///
  /// In en, this message translates to:
  /// **'New ad'**
  String get newAd;

  /// An ad's status: waiting for an admin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get adStatusPending;

  /// An ad's status: approved, showing on Discover.
  ///
  /// In en, this message translates to:
  /// **'Approved: showing'**
  String get adStatusApproved;

  /// An ad's status: rejected by an admin.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adStatusRejected;

  /// Confirmation title before deleting my ad.
  ///
  /// In en, this message translates to:
  /// **'Delete this ad?'**
  String get deleteAdQuestion;

  /// Confirmation text before deleting my ad.
  ///
  /// In en, this message translates to:
  /// **'It leaves Discover for good.'**
  String get deleteAdMessage;

  /// Ad editor field: the text shown over the ad.
  ///
  /// In en, this message translates to:
  /// **'Text over the ad'**
  String get adTextLabel;

  /// Ad editor field: where the ad links to.
  ///
  /// In en, this message translates to:
  /// **'Link (https://…)'**
  String get adLinkLabel;

  /// Ad editor: the link isn't a web address.
  ///
  /// In en, this message translates to:
  /// **'Enter a web address, starting with https://'**
  String get adLinkInvalid;

  /// Ad editor button: add a photo or video.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or video'**
  String get adAddMedia;

  /// Ad editor: remove the picked photo or video.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo or video'**
  String get adRemoveMedia;

  /// Ad editor: a video is picked (its preview).
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get adVideoPicked;

  /// Ad editor: nothing to show yet.
  ///
  /// In en, this message translates to:
  /// **'Add text, a photo or a video.'**
  String get adNeedsContent;

  /// Ad editor button: send the ad for an admin's review.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get adSubmit;

  /// Snackbar after sending an ad.
  ///
  /// In en, this message translates to:
  /// **'Sent: an admin will review it.'**
  String get adSent;

  /// Ad editor: heading over the preview of the card.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get adPreview;

  /// Ads tab when Premium has ended: can't add ads.
  ///
  /// In en, this message translates to:
  /// **'Your Premium has ended: your ads don\'t show. Renew it in your profile.'**
  String get adsNeedPremium;

  /// Admin tab's sub-navigation: everyone, to block.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsersTab;

  /// Admin tab's sub-navigation: ads to approve or reject.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get adminAdsTab;

  /// Admin screen title.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminAdsTitle;

  /// Admin ads: label of the frequency picker.
  ///
  /// In en, this message translates to:
  /// **'On Discover'**
  String get adsOnDiscover;

  /// Admin ads frequency: no ads on the deck.
  ///
  /// In en, this message translates to:
  /// **'No ads'**
  String get adEveryOff;

  /// Admin ads frequency: one ad after every N plans.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{An ad after every plan} other{An ad after every {count} plans}}'**
  String adEvery(int count);

  /// Admin: approve an ad.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adApprove;

  /// Admin: reject an ad.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adReject;

  /// Admin ads: none in this status.
  ///
  /// In en, this message translates to:
  /// **'No ads here'**
  String get adminAdsEmpty;

  /// Route finder (premium): the screen's title and the plan screen's button.
  ///
  /// In en, this message translates to:
  /// **'Routes on the rock'**
  String get routeFinder;

  /// Route finder (premium): routeFinderLoading.
  ///
  /// In en, this message translates to:
  /// **'Getting the walls here ready…'**
  String get routeFinderLoading;

  /// Route finder (premium): routeFinderNoWalls.
  ///
  /// In en, this message translates to:
  /// **'No walls known here yet. Record the first route.'**
  String get routeFinderNoWalls;

  /// Route finder: the wall in sight and how many routes it has.
  ///
  /// In en, this message translates to:
  /// **'{wall}: {count, plural, =0{no routes yet} =1{1 route} other{{count} routes}}'**
  String routeFinderSeen(String wall, int count);

  /// Route finder (premium): routeFinderPoint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the wall'**
  String get routeFinderPoint;

  /// Route finder (premium): routeFinderSnap.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the wall to find its routes'**
  String get routeFinderSnap;

  /// Route finder (premium): cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available.'**
  String get cameraUnavailable;

  /// Route finder (premium): recordRoute.
  ///
  /// In en, this message translates to:
  /// **'Record a route'**
  String get recordRoute;

  /// Route finder (premium): teachView.
  ///
  /// In en, this message translates to:
  /// **'Learn this view'**
  String get teachView;

  /// Route finder (premium): findRoutes.
  ///
  /// In en, this message translates to:
  /// **'Find routes'**
  String get findRoutes;

  /// Route finder (premium): learnedView.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Grigri knows this wall better now.'**
  String get learnedView;

  /// Route finder (premium): needTwoBolts.
  ///
  /// In en, this message translates to:
  /// **'Tap at least two bolts.'**
  String get needTwoBolts;

  /// Route finder (premium): routeSaved.
  ///
  /// In en, this message translates to:
  /// **'Route saved.'**
  String get routeSaved;

  /// Route finder (premium): undoBolt.
  ///
  /// In en, this message translates to:
  /// **'Undo the last bolt'**
  String get undoBolt;

  /// Route finder (premium): tapBolts.
  ///
  /// In en, this message translates to:
  /// **'Tap each bolt, from the ground up to the anchor'**
  String get tapBolts;

  /// Route finder (premium): tapBoltsNewWall.
  ///
  /// In en, this message translates to:
  /// **'New rock: tap each bolt, from the ground up. This photo will teach Grigri the wall.'**
  String get tapBoltsNewWall;

  /// Route finder (premium): notRecognized.
  ///
  /// In en, this message translates to:
  /// **'Grigri didn\'t recognize this wall.'**
  String get notRecognized;

  /// Route finder (premium): saveRoute.
  ///
  /// In en, this message translates to:
  /// **'Save the route'**
  String get saveRoute;

  /// Route finder (premium): newWallNote.
  ///
  /// In en, this message translates to:
  /// **'A new wall: this photo will teach Grigri what it looks like.'**
  String get newWallNote;

  /// Route finder (premium): wallName.
  ///
  /// In en, this message translates to:
  /// **'Wall'**
  String get wallName;

  /// Route finder (premium): routeName.
  ///
  /// In en, this message translates to:
  /// **'Route name'**
  String get routeName;

  /// Route finder (premium): routeScale.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeScale;

  /// Route finder (premium): boulderScale.
  ///
  /// In en, this message translates to:
  /// **'Boulder'**
  String get boulderScale;

  /// Route finder (premium): routeGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get routeGrade;

  /// Plan editor: how far a suggested crag is from me (km, one decimal under 10).
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String kmAway(String km);

  /// Plan editor section (shown uppercased): the plan's type.
  ///
  /// In en, this message translates to:
  /// **'Who can join'**
  String get sectionWhoCanJoin;

  /// Plan type: every member says yes to each newcomer (the default).
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get planTypePrivate;

  /// Plan type: anyone joins at once.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get planTypeOpen;

  /// Plan type: a guide's plan, paid; only the guide answers requests.
  ///
  /// In en, this message translates to:
  /// **'Guided'**
  String get planTypeGuided;

  /// Plan editor: what a private plan means.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the group says yes to each newcomer.'**
  String get planTypePrivateHint;

  /// Plan editor: what an open plan means.
  ///
  /// In en, this message translates to:
  /// **'Anyone can join at once, without waiting for a yes.'**
  String get planTypeOpenHint;

  /// Plan editor: what a guided plan means (the organizer is the guide).
  ///
  /// In en, this message translates to:
  /// **'You guide, and climbers pay you. Only you answer requests to join.'**
  String get planTypeGuidedHint;

  /// Plan editor: a guided plan's price field.
  ///
  /// In en, this message translates to:
  /// **'Price per climber'**
  String get pricePerClimber;

  /// Plan editor: the price isn't valid.
  ///
  /// In en, this message translates to:
  /// **'Enter a price above 0, with at most two decimals'**
  String get priceInvalid;

  /// Plan editor: the price's currency picker.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// Tag on a guided plan: its price per climber.
  ///
  /// In en, this message translates to:
  /// **'Guided · {price}'**
  String guidedPrice(String price);

  /// Under a guided plan's price: Grigri takes no payment.
  ///
  /// In en, this message translates to:
  /// **'Paid to the guide, not through Grigri.'**
  String get paidToGuide;

  /// Plan screen: on a guided plan, members other than the guide don't answer requests.
  ///
  /// In en, this message translates to:
  /// **'The guide decides'**
  String get theGuideDecides;

  /// Tag on an open plan's card: swiping right joins at once.
  ///
  /// In en, this message translates to:
  /// **'Open: join at once'**
  String get openJoinAtOnce;

  /// Sign-in screen: badge over the headline.
  ///
  /// In en, this message translates to:
  /// **'100% free'**
  String get signInBadge;

  /// Sign-in screen: the headline, Grigri's line.
  ///
  /// In en, this message translates to:
  /// **'Join a climbing plan.'**
  String get signInHeadline;

  /// Sign-in screen: under the sign-in button.
  ///
  /// In en, this message translates to:
  /// **'Free for every climber: no card, no subscription.'**
  String get signInFreeLine;

  /// Sign-in screen: the stamp on the demo card as it's swiped right.
  ///
  /// In en, this message translates to:
  /// **'JOIN'**
  String get signInStampJoin;

  /// Sign-in screen: the demo card's day, style and grades.
  ///
  /// In en, this message translates to:
  /// **'This Saturday · Sport · 6b–7a'**
  String get signInDeckWhen;

  /// Sign-in screen: the demo card's made-up climbers.
  ///
  /// In en, this message translates to:
  /// **'Mara, Jonas and 1 more'**
  String get signInDeckWho;

  /// Sign-in screen: heading of the three steps.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get signInHowTitle;

  /// Sign-in screen: step 1.
  ///
  /// In en, this message translates to:
  /// **'Make a plan'**
  String get signInStep1Title;

  /// Sign-in screen: step 1, explained.
  ///
  /// In en, this message translates to:
  /// **'Where, when and which grades: a crag, a Saturday, 6a to 7a.'**
  String get signInStep1Body;

  /// Sign-in screen: step 2.
  ///
  /// In en, this message translates to:
  /// **'Swipe right'**
  String get signInStep2Title;

  /// Sign-in screen: step 2, explained.
  ///
  /// In en, this message translates to:
  /// **'Like someone\'s plan? Swipe right. The group lets newcomers in one at a time, when everyone says yes.'**
  String get signInStep2Body;

  /// Sign-in screen: step 3.
  ///
  /// In en, this message translates to:
  /// **'Climb together'**
  String get signInStep3Title;

  /// Sign-in screen: step 3, explained.
  ///
  /// In en, this message translates to:
  /// **'Every match opens the plan\'s group chat: sort out the rope, the ride and the coffee.'**
  String get signInStep3Body;

  /// Sign-in screen: heading of what's free.
  ///
  /// In en, this message translates to:
  /// **'Free. Really.'**
  String get signInFreeTitle;

  /// Sign-in screen: a free feature.
  ///
  /// In en, this message translates to:
  /// **'Plans and swiping'**
  String get signInFree1;

  /// Sign-in screen: a free feature.
  ///
  /// In en, this message translates to:
  /// **'Matches and group chats'**
  String get signInFree2;

  /// Sign-in screen: a free feature.
  ///
  /// In en, this message translates to:
  /// **'Crag photos'**
  String get signInFree3;

  /// Sign-in screen: a free feature.
  ///
  /// In en, this message translates to:
  /// **'No card to sign up'**
  String get signInFree4;

  /// Sign-in screen: what Premium is for.
  ///
  /// In en, this message translates to:
  /// **'Premium is optional: it\'s only for advertising on Grigri and for the route finder. Climbing with Grigri costs nothing.'**
  String get signInFreePremium;

  /// Sign-in screen: the last call, at the bottom.
  ///
  /// In en, this message translates to:
  /// **'This weekend\'s climbing plan is one swipe away.'**
  String get signInFinalTitle;

  /// Sign-in screen: the last button.
  ///
  /// In en, this message translates to:
  /// **'Join free with Google'**
  String get signInJoinFree;

  /// Sign-in screen: the hero photo's credit.
  ///
  /// In en, this message translates to:
  /// **'Photo: {author}, {license}'**
  String signInPhotoBy(String author, String license);

  /// Sign-in screen: the second demo card's day, style and grades.
  ///
  /// In en, this message translates to:
  /// **'Sunday · Multi-pitch · 6a–6b'**
  String get signInDeckWhen2;

  /// Sign-in screen: the second demo card's made-up climbers.
  ///
  /// In en, this message translates to:
  /// **'Iker and Lea'**
  String get signInDeckWho2;

  /// Sign-in screen: the third demo card's day, style and grades.
  ///
  /// In en, this message translates to:
  /// **'Next weekend · Bouldering · 6C–7A'**
  String get signInDeckWhen3;

  /// Sign-in screen: the third demo card's made-up climbers.
  ///
  /// In en, this message translates to:
  /// **'Noor, Tomás and 2 more'**
  String get signInDeckWho3;

  /// Link at the end of Profile: opens the privacy policy on the site in the browser.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// Link at the end of Profile: opens the support page on the site in the browser.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// Profile: the button at the end that deletes my account for good.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Title of the delete-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountQuestion;

  /// Body of the delete-account confirmation dialog: what's deleted.
  ///
  /// In en, this message translates to:
  /// **'This deletes your Grigri account for good: your profile and photos, your messages and photos in group chats, your join requests and your ads. You leave all your plans: someone else in a plan you organize takes it over, and a plan with only you in it ends. Premium paid with a card here is cancelled at once, with no refund of the time left. A subscription bought through Apple must be cancelled in your iPhone\'s Settings. You\'re signed out on every device.'**
  String get deleteAccountMessage;

  /// Checkbox in the delete-account dialog; the delete button works only once it's ticked.
  ///
  /// In en, this message translates to:
  /// **'I understand this can\'t be undone'**
  String get deleteAccountUnderstand;

  /// The delete-account dialog's destructive button.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get deleteAccountConfirm;

  /// Snackbar: deleting the account failed (trying again finishes the job).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Try again.'**
  String get errorDeleteAccount;
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
