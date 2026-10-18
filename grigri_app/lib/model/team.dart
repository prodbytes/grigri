/// The Grigri team chat (specs/team-chat.md): every climber's own chat
/// with Grigri. The admins answer it as "Grigri team".
library;

DateTime _time(Object? value) => DateTime.parse(value! as String).toLocal();

/// A message in a team chat.
class TeamMessage {
  const TeamMessage({
    required this.id,
    required this.climberId,
    required this.fromTeam,
    required this.text,
    required this.time,
    this.adminId,
  });

  final String id;

  /// Whose team chat it is.
  final String climberId;

  /// Written for the Grigri team by an admin; false: by the climber.
  final bool fromTeam;
  final String text;
  final DateTime time;

  /// The admin who wrote it: only admins are told.
  final String? adminId;

  static TeamMessage fromJson(Map<String, Object?> json) => TeamMessage(
    id: json['id']! as String,
    climberId: json['climberId']! as String,
    fromTeam: json['fromTeam'] == true,
    text: json['text']! as String,
    time: _time(json['time']),
    adminId: json['adminId'] as String?,
  );
}

/// A climber's team chat in the admins' list: whose, and its last message.
class TeamChat {
  const TeamChat({
    required this.climberId,
    required this.lastTime,
    required this.lastText,
    required this.lastFromTeam,
  });

  final String climberId;
  final DateTime lastTime;
  final String lastText;

  /// The team answered last; false: the climber is waiting for an answer.
  final bool lastFromTeam;

  static TeamChat fromJson(Map<String, Object?> json) => TeamChat(
    climberId: json['climberId']! as String,
    lastTime: _time(json['lastTime']),
    lastText: json['lastText'] as String? ?? '',
    lastFromTeam: json['lastFromTeam'] == true,
  );
}
