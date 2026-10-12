import 'package:rbacr/rbacr.dart';

/// Where the user's roles come from: rbacr (https://rbacr.nu01.com), which
/// records the roles each identity holds in each system, Grigri's included.
class Roles {
  const Roles(Future<Me> Function() fetch) : _fetch = fetch;

  /// No rbacr: nobody is signed in to ask it as.
  const Roles.none() : _fetch = null;

  /// rbacr at `RBACR_URL` (else production), as the owner of the
  /// `RBACR_TOKEN` define. The run scripts pass that token only for a local
  /// rbacr (scripts/dart-defines.sh); without one this is [Roles.none], until
  /// sign-in gives the app the user's own token.
  factory Roles.fromSettings() {
    if (const String.fromEnvironment('RBACR_TOKEN').isEmpty) {
      return const Roles.none();
    }
    final client = RbacrClient();
    return Roles(client.me);
  }

  /// Grigri's system in rbacr.
  static const systemId = 'grigri';

  final Future<Me> Function()? _fetch;

  /// Whether there is an rbacr to ask.
  bool get available => _fetch != null;

  /// The user's roles in Grigri, sorted: their roles in its system and their
  /// global roles (`root` for rbacr's roots). Throws [RbacrException] when
  /// rbacr can't answer.
  Future<({String email, List<String> roles})> mine() async {
    final me = await _fetch!();
    final roles = {...?me.roles[systemId], ...me.globalRoles}.toList()..sort();
    return (email: me.email, roles: roles);
  }
}
