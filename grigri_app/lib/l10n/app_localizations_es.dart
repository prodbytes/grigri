// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get disciplineSport => 'Deportiva';

  @override
  String get disciplineTrad => 'Clásica';

  @override
  String get disciplineBouldering => 'Búlder';

  @override
  String get disciplineGym => 'Rocódromo';

  @override
  String get gradeSystemEuropean => 'Europeo';

  @override
  String get gradeSystemAmerican => 'Americano';

  @override
  String get gearRope => 'Cuerda';

  @override
  String get gearQuickdraws => 'Cintas exprés';

  @override
  String get gearRack => 'Material de autoprotección';

  @override
  String get gearCrashPad => 'Crash pad';

  @override
  String get gearCar => 'Coche';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get more => 'Más';

  @override
  String get refresh => 'Actualizar';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get retry => 'Reintentar';

  @override
  String get newPlan => 'Nuevo plan';

  @override
  String get you => 'Tú';

  @override
  String get youLower => 'tú';

  @override
  String get someone => 'Alguien';

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
    return '$yes de $total han dicho que sí';
  }

  @override
  String get declined => 'Rechazada';

  @override
  String get pending => 'Pendiente';

  @override
  String get accept => 'Aceptar';

  @override
  String get decline => 'Rechazar';

  @override
  String dayAndTime(String day, String time) {
    return '$day, $time';
  }

  @override
  String get errorGeneric => 'Algo ha fallado.';

  @override
  String errorStatus(int status) {
    return 'Algo ha fallado ($status).';
  }

  @override
  String get errorTimeout => 'El servidor ha tardado demasiado en responder.';

  @override
  String get errorUnreachable => 'No se ha podido conectar con el servidor.';

  @override
  String get errorPhotoTimeout => 'La subida de la foto ha tardado demasiado.';

  @override
  String get errorPhotoUnreachable => 'No se ha podido subir la foto.';

  @override
  String errorPhotoStatus(int status) {
    return 'La subida de la foto ha fallado ($status).';
  }

  @override
  String get errorPhotoType => 'Usa una foto JPEG, PNG o WebP.';

  @override
  String get errorSignedOut => 'Sesión cerrada: vuelve a iniciar sesión.';

  @override
  String get errorSignIn =>
      'No se ha podido iniciar sesión con Google. Inténtalo de nuevo.';

  @override
  String get errorSession =>
      'No se ha podido iniciar sesión. Inténtalo de nuevo.';

  @override
  String get errorSignOutEverywhere =>
      'No se ha podido cerrar sesión en todas partes. Inténtalo de nuevo.';

  @override
  String get loadFailedTitle => 'No se ha podido cargar tu perfil';

  @override
  String get signInTagline =>
      'Encuentra un plan de escalada: crea uno o desliza a la derecha en uno, y a escalar juntos.';

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get tabDiscover => 'Buscar';

  @override
  String get tabPlans => 'Planes';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabNotifications => 'Avisos';

  @override
  String get tabProfile => 'Yo';

  @override
  String get tabAdmin => 'Admin';

  @override
  String get thePlan => 'El plan';

  @override
  String get demoTag => 'Demo';

  @override
  String get demoNotice => 'Demo: personas y planes inventados.';

  @override
  String get yourGrades => 'Tu grado';

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
  String get signOutQuestion => '¿Cerrar sesión?';

  @override
  String get signOutMessage =>
      'Tu perfil, tus planes y tus chats se quedan guardados; vuelve a iniciar sesión para verlos.';

  @override
  String get signOutEverywhere => 'Cerrar sesión en todas partes';

  @override
  String get signOutEverywhereQuestion => '¿Cerrar sesión en todas partes?';

  @override
  String get signOutEverywhereMessage =>
      'Cierra tu sesión en todos los móviles y navegadores donde la iniciaste, también en este. Tu perfil, tus planes y tus chats se quedan guardados.';

  @override
  String get editProfile => 'Editar perfil';

  @override
  String get profileFootnote =>
      'Tu perfil habla de ti: qué escalas y qué material tienes. El cuándo y el dónde son para los planes, que se crean aparte en Planes.';

  @override
  String get takePhoto => 'Hacer una foto';

  @override
  String get choosePhoto => 'Elegir una foto';

  @override
  String get removePhoto => 'Quitar la foto';

  @override
  String get photoFailed => 'No se ha podido obtener la foto';

  @override
  String get addPhoto => 'Añadir una foto';

  @override
  String get changePhoto => 'Cambiar tu foto';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get nameRequired => 'Tu nombre, por favor';

  @override
  String get ageLabel => 'Edad (opcional)';

  @override
  String ageRange(int min, int max) {
    return 'De $min a $max';
  }

  @override
  String get bioLabel => 'Sobre ti';

  @override
  String get whatYouClimb => 'Qué escalas';

  @override
  String get whatYouClimbHint =>
      'Elige tus disciplinas y los grados que escalas.';

  @override
  String get gearYouCanBring => 'Material que puedes llevar';

  @override
  String get gearHint => 'Añade también fotos.';

  @override
  String gearPhoto(int number) {
    return 'Foto del material $number';
  }

  @override
  String removeGearPhoto(int number) {
    return 'Quitar la foto del material $number';
  }

  @override
  String get addGearPhoto => 'Añadir una foto del material';

  @override
  String get whereYouClimb => 'Dónde escalas';

  @override
  String get whereYouClimbHint =>
      'Los planes cercanos salen primero en Descubrir. Solo lo ves tú.';

  @override
  String get setYourLocation => 'Indica tu ubicación';

  @override
  String get yourLocation => 'Tu ubicación';

  @override
  String get clearYourLocation => 'Borrar tu ubicación';

  @override
  String removeArea(String name) {
    return 'Quitar $name';
  }

  @override
  String get addArea => 'Añadir una zona';

  @override
  String get locationSearchLabel => 'Una escuela o rocódromo cerca de allí';

  @override
  String get search => 'Buscar';

  @override
  String get locationPrivacy =>
      'Se guarda con una precisión de 1 km y solo la ves tú.';

  @override
  String placesAttribution(String attribution) {
    return 'Lugares: $attribution';
  }

  @override
  String get loadingPlaces => 'Cargando lugares…';

  @override
  String get noPlacesFound => 'No se han encontrado lugares';

  @override
  String get useCurrentLocation => 'Usar mi ubicación actual';

  @override
  String get locationNotFound =>
      'No se ha podido saber dónde estás. Busca un lugar.';

  @override
  String nearPlace(String place) {
    return 'Cerca de $place';
  }

  @override
  String get currentLocation => 'Donde estoy';

  @override
  String get setWhereYouClimbHint =>
      'Indica dónde escalas para ver primero los planes cercanos.';

  @override
  String get setAction => 'Indicar';

  @override
  String get discoverTitle => 'Descubre planes';

  @override
  String get askedToJoinSent =>
      'Solicitud enviada. Recibirás un aviso cuando te acepten.';

  @override
  String get noPlansToJoinTitle => 'Ahora mismo no hay planes';

  @override
  String get noPlansToJoinMessage =>
      'Aún nadie tiene un plan abierto para ti. Crea el tuyo: los escaladores que encajen pedirán unirse.';

  @override
  String get swipeJoin => 'Unirme';

  @override
  String get swipePass => 'Paso';

  @override
  String get pass => 'Pasar';

  @override
  String get askToJoin => 'Pedir unirme';

  @override
  String get sharePlan => 'Compartir este plan';

  @override
  String sharePlanText(
    String discipline,
    String place,
    String when,
    String link,
  ) {
    return 'Plan de escalada en Grigri: $discipline en $place, $when. $link';
  }

  @override
  String get organizedBy => 'Organiza';

  @override
  String get alsoInGroup => 'También en el grupo';

  @override
  String get showGroup => 'Ver el grupo';

  @override
  String get hideGroup => 'Ocultar el grupo';

  @override
  String get chatsTitle => 'Chats';

  @override
  String get noChatsTitle => 'Aún no hay chats';

  @override
  String get noChatsMessage =>
      'Cada plan en el que estás tiene un chat de grupo. Crea un plan, o pide unirte a uno, y su chat aparecerá aquí.';

  @override
  String get findPlan => 'Buscar un plan';

  @override
  String messagePreview(String author, String text) {
    return '$author: $text';
  }

  @override
  String toAnswer(int count) {
    return '$count por responder';
  }

  @override
  String get notInGroupTitle => 'No estás en este grupo';

  @override
  String get notInGroupMessage =>
      'Has dejado este plan, así que su chat está cerrado.';

  @override
  String get messageHint => 'Escribe al grupo';

  @override
  String get send => 'Enviar';

  @override
  String get wantsToJoinYourAnswer => 'Quiere unirse · tu respuesta';

  @override
  String declineName(String name) {
    return 'Rechazar a $name';
  }

  @override
  String acceptName(String name) {
    return 'Aceptar a $name';
  }

  @override
  String askedToJoinAt(String time) {
    return 'Pidió unirse · $time';
  }

  @override
  String noGradesYet(String discipline) {
    String _temp0 = intl.Intl.selectLogic(discipline, {
      'sport': 'Aún sin grado en deportiva',
      'trad': 'Aún sin grado en clásica',
      'bouldering': 'Aún sin grado en búlder',
      'gym': 'Aún sin grado en rocódromo',
      'other': 'Aún sin grado',
    });
    return '$_temp0';
  }

  @override
  String get joined => 'Se ha unido';

  @override
  String get closed => 'Cerrada';

  @override
  String namesSaidYes(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Han dicho que sí: $names',
      one: 'Ha dicho que sí: $names',
    );
    return '$_temp0';
  }

  @override
  String waitingFor(String names) {
    return 'falta $names';
  }

  @override
  String get itsAMatch => '¡Hay match!';

  @override
  String get matchEveryoneSaidYes =>
      'Todo el grupo ha dicho que sí. Escaláis juntos:';

  @override
  String matchJoinsGroup(String name) {
    return '$name se une al grupo:';
  }

  @override
  String get openGroupChat => 'Abrir el chat del grupo';

  @override
  String get keepSwiping => 'Seguir deslizando';

  @override
  String get notificationsTitle => 'Avisos';

  @override
  String get nothingYetTitle => 'Nada todavía';

  @override
  String get nothingYetMessage =>
      'Cuando alguien pida unirse a un plan en el que estás, o un grupo responda a tu solicitud, te enterarás aquí.';

  @override
  String noticeWantsToJoin(String name) {
    return '$name quiere unirse';
  }

  @override
  String noticeAnswerInChat(String plan) {
    return '$plan · responde en el chat del grupo';
  }

  @override
  String noticeYoureIn(String plan) {
    return 'Estás dentro: $plan';
  }

  @override
  String get noticeAcceptedBody =>
      'El grupo te ha aceptado. Saluda en el chat.';

  @override
  String noticeNotThisTime(String plan) {
    return 'Esta vez no: $plan';
  }

  @override
  String get noticeDeclinedBody => 'El grupo ha rechazado tu solicitud.';

  @override
  String get newTag => 'Nuevo';

  @override
  String get planGoneTitle => 'El plan ya no existe';

  @override
  String get planGoneMessage =>
      'Todos han dejado este plan, o ya no está abierto.';

  @override
  String get yourPlan => 'Tu plan';

  @override
  String get planTitle => 'Plan';

  @override
  String get edit => 'Editar';

  @override
  String get declinedGroupSaidNo => 'Rechazada: el grupo ha dicho que no';

  @override
  String pendingSaidYes(int yes, int total) {
    return 'Pendiente: $yes de $total han dicho que sí';
  }

  @override
  String theGroupCount(int count) {
    return 'El grupo · $count';
  }

  @override
  String get organizer => 'Organizador';

  @override
  String get member => 'Miembro';

  @override
  String get askingToJoin => 'Quieren unirse';

  @override
  String get youSaidYes => 'Has dicho que sí';

  @override
  String get answerInChat => 'Responde en el chat';

  @override
  String get groupChat => 'Chat del grupo';

  @override
  String get cancelPlan => 'Cancelar el plan';

  @override
  String get cancelPlanQuestion => '¿Cancelar el plan?';

  @override
  String get cancelPlanMessage => 'El plan y su chat desaparecerán.';

  @override
  String get cancelPlanOthersMessage =>
      'Saldrá de tus planes y chats; los demás lo conservan. No podrás volver a unirte.';

  @override
  String get cancelPlanOrganizerMessage =>
      'Saldrá de tus planes y chats; los demás lo conservan y uno de ellos, elegido al azar, lo organizará. No podrás volver a unirte.';

  @override
  String get keepPlan => 'Mantenerlo';

  @override
  String get confirmCancelPlan => 'Cancelarlo';

  @override
  String get editPlan => 'Editar plan';

  @override
  String get pickFutureTime => 'Elige una hora que aún no haya pasado.';

  @override
  String get sectorLabel => 'Sector, escuela o rocódromo';

  @override
  String get sectorHint => 'Busca o escríbelo';

  @override
  String sectorsAttribution(String attribution) {
    return 'Sectores: $attribution';
  }

  @override
  String get whereRequired => '¿Dónde vas a escalar?';

  @override
  String get sectionDiscipline => 'Escalada';

  @override
  String get sectionWhere => 'Dónde';

  @override
  String get sectionWhen => 'Cuándo';

  @override
  String get dateToBeDecided => 'Fecha por decidir';

  @override
  String dayAndMoreDays(String day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$day +$_temp0';
  }

  @override
  String get addDay => 'Añadir un día';

  @override
  String get leaveDateOpen => 'Dejar la fecha abierta';

  @override
  String get whenHelp =>
      'La fecha es opcional. Añade más días para una salida más larga.';

  @override
  String get sectionGrades => 'Grados';

  @override
  String get sectionNotes => 'Notas';

  @override
  String get notesHint =>
      'Punto de encuentro, plazas en el coche, las vías que tienes en mente…';

  @override
  String get publishPlan => 'Publicar el plan';

  @override
  String get yourPlans => 'Tus planes';

  @override
  String get noPlansYetTitle => 'Aún no hay planes';

  @override
  String get noPlansYetMessage =>
      'Crea un plan (qué, dónde, cuándo) y los escaladores que encajen pedirán unirse. O desliza a la derecha en uno en Descubrir.';

  @override
  String get plansClimbing => 'Escalando';

  @override
  String get plansAskedToJoin => 'Solicitados';

  @override
  String get organizing => 'Organizas tú';

  @override
  String get accepted => 'Aceptado';

  @override
  String toReview(int count) {
    return '$count por revisar';
  }

  @override
  String get groupSaidNo => 'El grupo ha dicho que no';

  @override
  String waitingForNames(String names) {
    return 'Falta: $names';
  }

  @override
  String get dismiss => 'Descartar';

  @override
  String get adminTitle => 'Admin: personas';

  @override
  String get roles => 'Roles';

  @override
  String get rolesFailed => 'No se han podido obtener tus roles de rbacr.';

  @override
  String get noRoles => 'Aún no tienes roles en Grigri.';

  @override
  String get nudge => 'Recordar';

  @override
  String get nudged => 'Recordado';

  @override
  String get nudgeTooltip =>
      'Recuerda al grupo que responda (una vez cada 12 horas)';

  @override
  String nudgeSent(String names) {
    return 'Recordatorio enviado a $names';
  }

  @override
  String noticeNudgeTitle(String name) {
    return '$name espera tu respuesta';
  }

  @override
  String noticeNudgeBody(String plan) {
    return 'Para unirse a $plan · acepta o rechaza en el chat del grupo';
  }

  @override
  String get attachMedia => 'Añadir una foto o un vídeo';

  @override
  String get recordVideo => 'Grabar un vídeo';

  @override
  String get chooseVideo => 'Elegir un vídeo';

  @override
  String get photoMessage => 'Foto';

  @override
  String get videoMessage => 'Vídeo';

  @override
  String get removeAttachment => 'Quitar el adjunto';

  @override
  String get uploadingMedia => 'Subiendo…';

  @override
  String get playVideo => 'Reproducir el vídeo';

  @override
  String get videoUnavailable => 'Este vídeo no se puede reproducir.';

  @override
  String get mediaUnavailable => 'No disponible';

  @override
  String get errorMediaType =>
      'Usa una foto JPEG, PNG o WebP, o un vídeo MP4 o MOV.';

  @override
  String errorVideoTooBig(int mb) {
    return 'Los vídeos pueden ocupar como mucho $mb MB: envía uno más corto.';
  }

  @override
  String matchScore(int percent, String level) {
    return 'Afinidad $percent% · $level';
  }

  @override
  String get matchLevelLongShot => 'poco probable';

  @override
  String get matchLevelPossible => 'posible';

  @override
  String get matchLevelGood => 'buena';

  @override
  String get matchLevelGreat => 'excelente';

  @override
  String get matchReasonOtherDiscipline => 'No escalas esta disciplina';

  @override
  String get matchReasonTooHard =>
      'Sus grados están muy por encima de los tuyos';

  @override
  String get matchReasonTooEasy =>
      'Sus grados están muy por debajo de los tuyos';

  @override
  String get matchReasonStartsSoon => 'Empieza en menos de 12 horas';

  @override
  String get matchReasonFar => 'A más de 100 km';

  @override
  String get matchReasonBigGroup =>
      'Cinco o más personas tienen que decir que sí';

  @override
  String get matchReasonCrowded => 'Hay diez o más esperando';

  @override
  String get matchReasonInGradesNearby => 'En tus grados y cerca';

  @override
  String get matchReasonInGrades => 'En tus grados';

  @override
  String get matchReasonCloseGrades => 'A uno o dos grados de los tuyos';

  @override
  String get adminNoClimbersTitle => 'Nadie todavía';

  @override
  String get adminNoClimbersMessage =>
      'Aquí aparece todo el que tiene perfil, para bloquearlo o desbloquearlo.';

  @override
  String get block => 'Bloquear';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get blocked => 'Bloqueado';

  @override
  String blockNameQuestion(String name) {
    return '¿Bloquear a $name?';
  }

  @override
  String get blockMessage =>
      'No podrá usar Grigri hasta que lo desbloquees, y sus planes salen de Descubrir para todos.';

  @override
  String get blockedTitle => 'Tu cuenta está bloqueada';

  @override
  String get blockedMessage =>
      'Un administrador bloqueó tu cuenta, así que de momento no puedes usar Grigri.';

  @override
  String get yourPics => 'Tus fotos';

  @override
  String get grigriPics => 'GriGri Pics';

  @override
  String get yourPicsEmpty => 'Aún no hay fotos. Añade una o envíala al chat.';

  @override
  String get grigriPicsEmpty => 'Aún no hay GriGri Pics de este lugar.';

  @override
  String get addPlanPic => 'Añadir una foto al plan';

  @override
  String get deletePic => 'Borrar la foto';

  @override
  String get deletePicQuestion => '¿Borrar esta foto?';

  @override
  String get deletePicMessage => 'Sale de las fotos del plan para todos.';

  @override
  String get deleteChatPicMessage =>
      'Sale de las fotos del plan; el chat la conserva.';

  @override
  String get delete => 'Borrar';

  @override
  String picCredit(String author, String license) {
    return 'Foto: $author, $license';
  }

  @override
  String picAddedBy(String name) {
    return 'Añadida por $name';
  }

  @override
  String picFromChat(String name) {
    return 'Enviada al chat por $name';
  }

  @override
  String get premiumTitle => 'Grigri Premium';

  @override
  String get premiumPitch =>
      'Anúnciate en Grigri: tus anuncios salen entre los planes en Buscar de todo el mundo. Todo lo demás sigue igual.';

  @override
  String premiumMonthly(String price) {
    return '$price al mes';
  }

  @override
  String premiumYearly(String price) {
    return '$price al año';
  }

  @override
  String get premiumCheckoutHint =>
      'Pagas en la página segura de Stripe, en tu navegador. Vuelve aquí cuando acabes.';

  @override
  String premiumActiveUntil(String date) {
    return 'Premium: se renueva el $date';
  }

  @override
  String premiumEndsOn(String date) {
    return 'Premium: termina el $date';
  }

  @override
  String get premiumManage => 'Gestionar suscripción';

  @override
  String get premiumUnavailable => 'Premium aún no está disponible.';

  @override
  String get premiumCheckRefresh => 'Ya he pagado: comprobar';

  @override
  String get errorOpenLink => 'No se pudo abrir el enlace.';

  @override
  String get tabAds => 'Anuncios';

  @override
  String get adTag => 'Anuncio';

  @override
  String adBy(String name) {
    return 'Anuncio de $name';
  }

  @override
  String get swipeOpen => 'Abrir';

  @override
  String get swipeSkip => 'Saltar';

  @override
  String get openAd => 'Abrir el enlace del anuncio';

  @override
  String get skipAd => 'Saltar el anuncio';

  @override
  String get shareAd => 'Compartir el enlace del anuncio';

  @override
  String get adsTitle => 'Tus anuncios';

  @override
  String get adsEmptyTitle => 'Aún no hay anuncios';

  @override
  String get adsEmptyMessage =>
      'Añade un anuncio: cuando un admin lo apruebe, saldrá entre los planes en Buscar de todo el mundo.';

  @override
  String get newAd => 'Nuevo anuncio';

  @override
  String get adStatusPending => 'Pendiente de revisión';

  @override
  String get adStatusApproved => 'Aprobado: se muestra';

  @override
  String get adStatusRejected => 'Rechazado';

  @override
  String get deleteAdQuestion => '¿Eliminar este anuncio?';

  @override
  String get deleteAdMessage => 'Desaparecerá de Buscar para siempre.';

  @override
  String get adTextLabel => 'Texto sobre el anuncio';

  @override
  String get adLinkLabel => 'Enlace (https://…)';

  @override
  String get adLinkInvalid =>
      'Escribe una dirección web que empiece por https://';

  @override
  String get adAddMedia => 'Añadir foto o vídeo';

  @override
  String get adRemoveMedia => 'Quitar la foto o el vídeo';

  @override
  String get adVideoPicked => 'Vídeo';

  @override
  String get adNeedsContent => 'Añade texto, una foto o un vídeo.';

  @override
  String get adSubmit => 'Enviar a revisión';

  @override
  String get adSent => 'Enviado: un admin lo revisará.';

  @override
  String get adPreview => 'Vista previa';

  @override
  String get adsNeedPremium =>
      'Tu Premium ha terminado: tus anuncios no se muestran. Renuévalo en tu perfil.';

  @override
  String get adminUsersTab => 'Usuarios';

  @override
  String get adminAdsTab => 'Anuncios';

  @override
  String get adminAdsTitle => 'Admin';

  @override
  String get adsOnDiscover => 'En Buscar';

  @override
  String get adEveryOff => 'Sin anuncios';

  @override
  String adEvery(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Un anuncio cada $count planes',
      one: 'Un anuncio tras cada plan',
    );
    return '$_temp0';
  }

  @override
  String get adApprove => 'Aprobar';

  @override
  String get adReject => 'Rechazar';

  @override
  String get adminAdsEmpty => 'No hay anuncios aquí';

  @override
  String get routeFinder => 'Vías en la roca';

  @override
  String get routeFinderLoading => 'Preparando las paredes de aquí…';

  @override
  String get routeFinderNoWalls =>
      'Aún no hay paredes conocidas aquí. Registra la primera vía.';

  @override
  String routeFinderSeen(String wall, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vías',
      one: '1 vía',
      zero: 'aún sin vías',
    );
    return '$wall: $_temp0';
  }

  @override
  String get routeFinderPoint => 'Apunta la cámara a la pared';

  @override
  String get routeFinderSnap =>
      'Haz una foto de la pared para encontrar sus vías';

  @override
  String get cameraUnavailable => 'La cámara no está disponible.';

  @override
  String get recordRoute => 'Registrar una vía';

  @override
  String get teachView => 'Aprender esta vista';

  @override
  String get findRoutes => 'Encontrar vías';

  @override
  String get learnedView => '¡Gracias! Grigri ya conoce mejor esta pared.';

  @override
  String get needTwoBolts => 'Toca al menos dos chapas.';

  @override
  String get routeSaved => 'Vía guardada.';

  @override
  String get undoBolt => 'Deshacer la última chapa';

  @override
  String get tapBolts => 'Toca cada chapa, desde el suelo hasta la reunión';

  @override
  String get tapBoltsNewWall =>
      'Roca nueva: toca cada chapa, desde el suelo. Esta foto enseñará la pared a Grigri.';

  @override
  String get notRecognized => 'Grigri no ha reconocido esta pared.';

  @override
  String get saveRoute => 'Guardar la vía';

  @override
  String get newWallNote =>
      'Una pared nueva: esta foto enseñará a Grigri cómo es.';

  @override
  String get wallName => 'Pared';

  @override
  String get routeName => 'Nombre de la vía';

  @override
  String get routeScale => 'Vía';

  @override
  String get boulderScale => 'Bloque';

  @override
  String get routeGrade => 'Grado';

  @override
  String kmAway(String km) {
    return '$km km';
  }

  @override
  String get sectionWhoCanJoin => 'Quién puede unirse';

  @override
  String get planTypePrivate => 'Privado';

  @override
  String get planTypeOpen => 'Abierto';

  @override
  String get planTypeGuided => 'Guiado';

  @override
  String get planTypePrivateHint => 'Todo el grupo dice que sí a cada nuevo.';

  @override
  String get planTypeOpenHint =>
      'Cualquiera puede unirse al momento, sin esperar un sí.';

  @override
  String get planTypeGuidedHint =>
      'Tú guías y los escaladores te pagan. Solo tú respondes a las solicitudes.';

  @override
  String get pricePerClimber => 'Precio por escalador';

  @override
  String get priceInvalid =>
      'Pon un precio mayor que 0, con dos decimales como mucho';

  @override
  String get currency => 'Moneda';

  @override
  String guidedPrice(String price) {
    return 'Guiado · $price';
  }

  @override
  String get paidToGuide => 'Se paga al guía, no a través de Grigri.';

  @override
  String get theGuideDecides => 'Decide el guía';

  @override
  String get openJoinAtOnce => 'Abierto: únete al momento';
}
