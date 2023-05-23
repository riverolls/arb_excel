import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

/// To match all args from a text.
final _kRegArgs = RegExp(r'{(\w+)}');
const _metaSymbol = '@';
const _tab = '    ';

/// Parses .arb files to [Translation].
/// The [filename] is the main language.
Translation parseARB(String folderPath) {
  final folder = Directory(folderPath);
  if (!folder.existsSync()) {
    throw FileSystemException('Directory $folderPath does not exists');
  }
  final items = <ARBItem>[];
  final languages = <String>{};
  for (final entity in folder.listSync(followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.arb')) continue;
    final bytes = entity.readAsBytesSync();
    final body = Utf8Decoder().convert(bytes);
    final jsonBody = json.decode(body) as Map<String, dynamic>;
    final textKeys =
        jsonBody.keys.where((element) => !element.startsWith(_metaSymbol));
    final language = withoutExtension(entity.path).split('_').last;
    if (!languages.contains(language)) languages.add(language);
    for (final textKey in textKeys) {
      final text = jsonBody[textKey];
      if (text is! String) continue;
      String? description;
      String? category;
      final metadata = jsonBody[_metaSymbol + textKey];
      if (metadata is Map<String, dynamic>) {
        description = metadata['description'];
        category = metadata['type'];
      }
      final indexExists = items.indexWhere((e) => e.text == textKey);
      if (indexExists == -1) {
        items.add(
          ARBItem(
            category: category,
            text: textKey,
            description: description,
            translations: {
              language: text,
            },
          ),
        );
      } else {
        items[indexExists] = ARBItem(
          category: items[indexExists].category ?? category,
          text: textKey,
          description: items[indexExists].description ?? description,
          translations: {
            language: text,
            ...items[indexExists].translations,
          },
        );
      }
    }
  }
  return Translation(languages: languages.toList(), items: items);
}

/// Writes [Translation] to .arb files.
void writeARB(String filename, Translation data) {
  for (var i = 0; i < data.languages.length; i++) {
    final lang = data.languages[i];
    final isDefault = i == 0;
    final f = File('${withoutExtension(filename)}_$lang.arb');

    var buf = [];
    for (final item in data.items) {
      final data = item.toJSON(lang, isDefault);
      if (data != null) {
        buf.add(item.toJSON(lang, isDefault));
      }
    }

    buf = ['{', '$_tab"@@locale": "$lang",', buf.join(',\n'), '}\n'];
    f.writeAsStringSync(buf.join('\n'));
  }
}

/// Describes an ARB record.
class ARBItem {
  static List<String> getArgs(String text) {
    final List<String> args = [];
    final matches = _kRegArgs.allMatches(text);
    for (final m in matches) {
      final arg = m.group(1);
      if (arg != null) {
        args.add(arg);
      }
    }

    return args;
  }

  ARBItem({
    this.category,
    required this.text,
    this.description,
    this.translations = const {},
  });

  final String? category;
  final String text;
  final String? description;
  final Map<String, String> translations;

  /// Serialize in JSON.
  String? toJSON(String lang, [bool isDefault = false]) {
    final value = translations[lang];
    if (value == null || value.isEmpty) return null;

    final args = getArgs(value);
    final hasMetadata = isDefault && (args.isNotEmpty || description != null);

    final List<String> buf = [];

    if (hasMetadata) {
      buf.add('$_tab"$text": "$value",');
      buf.add('$_tab"@$text": {');

      if (args.isEmpty) {
        if (description != null) {
          buf.add('${_tab * 2}"description": "$description"');
        }
      } else {
        if (description != null) {
          buf.add('${_tab * 2}"description": "$description",');
        }

        buf.add('${_tab * 2}"placeholders": {');
        final List<String> group = [];
        for (final arg in args) {
          group.add('${_tab * 3}"$arg": {"type": "String"}');
        }
        buf.add(group.join(',\n'));
        buf.add('${_tab * 2}}');
      }

      buf.add('$_tab}');
    } else {
      buf.add('$_tab"$text": "$value"');
    }

    return buf.join('\n');
  }
}

/// Describes all arb records.
class Translation {
  Translation({this.languages = const [], this.items = const []});

  final List<String> languages;
  final List<ARBItem> items;
}
