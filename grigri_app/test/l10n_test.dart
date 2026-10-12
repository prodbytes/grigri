// Keeps the translation bundles up to date: every bundle has exactly the
// template's keys, with the same placeholders (specs/i18n.md).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/ui/l10n.dart';

const _dir = 'lib/l10n';
const _template = 'app_en.arb';

Map<String, Object?> _read(String name) =>
    (jsonDecode(File('$_dir/$name').readAsStringSync()) as Map).cast();

/// The messages of a bundle, without its metadata (`@key`, `@@locale`).
Map<String, String> _messages(Map<String, Object?> arb) => {
  for (final e in arb.entries)
    if (!e.key.startsWith('@')) e.key: e.value! as String,
};

/// The placeholders a message uses: `{name}`, and the variable of a
/// `{count, plural, ...}` or `{x, select, ...}`.
Set<String> _placeholders(String message) => {
  for (final m in RegExp(r'\{\s*(\w+)\s*[,}]').allMatches(message)) m[1]!,
};

void main() {
  final template = _read(_template);
  final english = _messages(template);
  final bundles = {
    for (final f in Directory(_dir).listSync().whereType<File>())
      if (f.path.endsWith('.arb')) f.uri.pathSegments.last,
  };

  test('there is a bundle for every language the app offers', () {
    expect(bundles, {for (final code in languageNames.keys) 'app_$code.arb'});
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      languageNames.keys.toSet(),
    );
    expect(
      AppLocalizations.supportedLocales.first,
      const Locale('en'),
      reason: 'English is the fallback',
    );
  });

  test('every template message is described, with its placeholders', () {
    for (final MapEntry(:key, :value) in english.entries) {
      final meta = template['@$key'] as Map?;
      expect(meta?['description'], isA<String>(), reason: '@$key description');
      final declared = ((meta?['placeholders'] as Map?) ?? {}).keys.toSet();
      expect(declared, _placeholders(value), reason: '@$key placeholders');
    }
  });

  for (final name in bundles.difference({_template})) {
    group(name, () {
      final arb = _read(name);
      final messages = _messages(arb);

      test('says its locale', () {
        expect(arb['@@locale'], name.substring(4, name.length - 4));
      });

      test('has every key of the template, and no others', () {
        expect(
          english.keys.toSet().difference(messages.keys.toSet()),
          isEmpty,
          reason: 'missing from $name',
        );
        expect(
          messages.keys.toSet().difference(english.keys.toSet()),
          isEmpty,
          reason: 'in $name but not in $_template',
        );
      });

      test('uses the same placeholders as the template', () {
        for (final MapEntry(:key, :value) in messages.entries) {
          if (english[key] case final en?) {
            expect(_placeholders(value), _placeholders(en), reason: key);
          }
        }
      });
    });
  }
}
