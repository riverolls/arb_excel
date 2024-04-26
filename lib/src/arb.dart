import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

/// To match all args from a text.
final _kRegArgs = RegExp(r'{(\w+)}');
const _metaSymbol = '@';
const _tab = '  ';

/// Parses .arb files to [Translation].
/// The [filename] is the main language.
Translation parseARB(String folderPath, String defaultLanguage) {
  // 获取文件夹
  final folder = Directory(folderPath);
  if (!folder.existsSync()) {
    throw FileSystemException('Directory $folderPath does not exists');
  }
  final items = <ARBItem>[];
  final languages = <String>{};
  // 获取 arb 文件
  List<FileSystemEntity> folderList = folder
      .listSync(followLinks: false)
      .where((element) => element is File && element.path.endsWith('.arb'))
      .toList();
  // 查找列表中有没有默认语言对应的文件
  final defaultLangIndex = folderList.indexWhere((element) =>
      withoutExtension(element.path).split('_').last == defaultLanguage);
  if (defaultLangIndex > 0) {
    // 如果存在，将默认语言文件放在首位
    var item = folderList.removeAt(defaultLangIndex);
    folderList.insert(0, item);
  }
  // 遍历文件夹
  for (final entity in folderList) {
    // 如果不是 arb 后缀就跳过
    if (entity is! File || !entity.path.endsWith('.arb')) continue;
    // print('**************************** 语言分界线 ****************************');
    final bytes = entity.readAsBytesSync();
    final body = Utf8Decoder().convert(bytes);
    final jsonBody = json.decode(body) as Map<String, dynamic>;
    // 字段列表
    final textKeys =
        jsonBody.keys.where((element) => !element.startsWith(_metaSymbol));
    // 解析获取语言类型
    final language = jsonBody['@@locale'] as String? ??
        withoutExtension(entity.path).split('_').last;
    // 收集语言
    if (!languages.contains(language)) languages.add(language);
    for (final textKey in textKeys) {
      final value = jsonBody[textKey];
      if (value is! String) continue;
      String? description;
      String? category;
      String? placeholders;
      // 收集描述信息
      final metadata = jsonBody[_metaSymbol + textKey];
      if (metadata is Map<String, dynamic>) {
        description = metadata['description'];
        category = metadata['type'];
        if (metadata.containsKey('placeholders')) {
          placeholders = json.encode(metadata['placeholders']).trim();
        }
      }
      final indexExists = items.indexWhere((e) => e.key == textKey);
      if (indexExists == -1) {
        // 如果不存在字段，添加到列表
        // print('添加: $textKey, 语言: $language, value: $value');
        items.add(
          ARBItem(
            category: category,
            key: textKey,
            description: description,
            placeholders: placeholders,
            translations: {
              language: value,
            },
          ),
        );
      } else {
        // 存在字段，更新列表
        // print('更新: $textKey, 语言: $language, value: $value');
        items[indexExists] = ARBItem(
          category: items[indexExists].category ?? category,
          key: textKey,
          description: items[indexExists].description ?? description,
          placeholders: items[indexExists].placeholders ?? placeholders,
          translations: {
            language: value,
            ...items[indexExists].translations,
          },
        );
      }
    }
  }
  return Translation(languages: languages.toList(), items: items);
}

/// Writes [Translation] to .arb files.
void writeARB(String filename, Translation data, String defaultLang) {
  bool hasDefault = false;
  for (final lang in data.languages) {
    if (defaultLang == lang) {
      hasDefault = true;
      break;
    }
  }
  for (var i = 0; i < data.languages.length; i++) {
    final lang = data.languages[i];
    final isDefault = hasDefault ? lang == defaultLang : i == 0;

    final f = File('${withoutExtension(filename)}intl_$lang.arb');
    if (!f.existsSync()) {
      f.createSync(recursive: true);
    }

    var buf = [];
    for (final item in data.items) {
      final jsonData = item.toJSON(lang, isDefault);
      if (jsonData != null) {
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
    required this.key,
    this.description,
    this.placeholders,
    required this.translations,
  });

  final String? category;
  final String? placeholders;
  final String key;
  final String? description;
  final Map<String, String> translations;

  /// 将 value 的特殊符号转义
  String convertValue(String text) {
    // 匹配双引号
    var result = '';
    final reg1 = RegExp(r'"');
    for (var i = 0; i < text.length; i++) {
      var char = text[i];
      char = char.replaceAll(reg1, '\\"');
      result += char;
    }
    return result;
  }

  /// Serialize in JSON.
  String? toJSON(String lang, [bool isDefault = false]) {
    final value = translations[lang];
    if (value == null || value.isEmpty) return null;

    final args = getArgs(value);
    final hasMetadata =
        isDefault && (args.isNotEmpty || (description?.isNotEmpty ?? false));

    final List<String> buf = [];

    if (hasMetadata) {
      buf.add('$_tab"$key": "${convertValue(value)}",');
      buf.add('$_tab"@$key": {');
      if (args.isEmpty) {
        if (description != null && description!.isNotEmpty) {
          // 不存在参数，description 后不需要加逗号
          buf.add('${_tab * 2}"description": "$description"');
        }
      } else {
        if (description != null && description!.isNotEmpty) {
          // 存在参数，并且 placeholders 不为空，description 后需要加逗号
          if (placeholders != null && placeholders!.trim().isNotEmpty) {
            buf.add('${_tab * 2}"description": "$description",');
          } else {
            buf.add('${_tab * 2}"description": "$description"');
          }
        }
        if (placeholders != null && placeholders!.trim().isNotEmpty) {
          final map = json.decode(placeholders!);
          // 将map中的key和value都加上双引号
          final Map<String, dynamic> newMap = quoteKeyValue(map);
          buf.add('${_tab * 2}"placeholders": $newMap');
        } else {
          print(
              'text = $key 存在参数$args, 但是没有填写 placeholders, 需要填写 placeholders 为 $args 添加描述信息');
        }

        // buf.add('${_tab * 2}"placeholders": {');
        // final List<String> group = [];
        // for (final arg in args) {
        //   group.add('${_tab * 3}"$arg": {"type": "String"}');
        // }
        // buf.add(group.join(',\n'));
        // buf.add('${_tab * 2}}');
      }

      buf.add('$_tab}');
    } else {
      buf.add('$_tab"$key": "${convertValue(value)}"');
    }

    return buf.join('\n');
  }
}

Map<String, dynamic> quoteKeyValue(Map map) {
  Map<String, dynamic> newMap = {};
  map.forEach((key, value) {
    if (value is String) {
      newMap['"$key"'] = '"$value"';
    } else if (value is Map) {
      newMap['"$key"'] = quoteKeyValue(value);
    }
  });
  return newMap;
}

/// Describes all arb records.
class Translation {
  Translation({this.languages = const [], this.items = const []});

  final List<String> languages;
  final List<ARBItem> items;
}
