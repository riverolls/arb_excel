import 'dart:convert';
import 'dart:io';

import 'package:arb_excel/src/assets.dart';
import 'package:excel/excel.dart';

import 'arb.dart';

const _kRowHeader = 0;
const _kRowValue = 1;
const _kColCategory = 0;
const _kColText = 1;
const _kColDescription = 2;
const _kColPlaceholders = 3;
const _kColValue = 4;

/// Create a new Excel template file.
///
/// Embedded data will be packed via `template.dart`.
void newTemplate(String filename) {
  final buf = base64Decode(kTemplate);
  File(filename).writeAsBytesSync(buf);
}

/// Reads Excel sheet.
///
/// Uses `arb_sheet -n path/to/file` to create a translation file
/// from the template.
Translation parseExcel({
  required String filename,
  String? sheetName,
  int headerRow = _kRowHeader,
  int valueRow = _kRowValue,
}) {
  final buf = File(filename).readAsBytesSync();
  final excel = Excel.decodeBytes(buf);
  final sheet = excel.sheets[sheetName ?? excel.sheets.keys.first];
  if (sheet == null) {
    return Translation();
  }

  final List<ARBItem> items = [];
  final columns = sheet.rows[headerRow];
  for (int i = valueRow; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    final placeholders = row[_kColPlaceholders]?.value?.toString();
    final item = ARBItem(
      category: row[_kColCategory]?.value?.toString(),
      key: row[_kColText]?.value?.toString() ?? '',
      description:
          row[_kColDescription]?.value?.toString().replaceAll('\n', '\\n'),
      placeholders: placeholders,
      translations: {},
    );

    for (int i = _kColValue; i < sheet.maxCols; i++) {
      final lang = columns[i]?.value?.toString() ?? i.toString();
      item.translations[lang] =
          row[i]?.value?.toString().replaceAll('\n', '\\n') ?? '';
    }

    items.add(item);
  }

  final languages = columns
      .where((e) => e != null && e.colIndex >= _kColValue)
      .map<String>((e) => e?.value?.toString() ?? '')
      .toList();
  return Translation(languages: languages, items: items);
}

/// Writes a Excel file, includes all translations.
void writeExcel(String filename, Translation data) {
  final excel = Excel.createExcel();
  //library creates one sheet by default
  final sheetname = excel.sheets.keys.first;
  final sheet = excel[sheetname];
  final headerRow = ['category', 'text', 'description','placeholders', ...data.languages];
  sheet.appendRow(headerRow);
  for (final item in data.items) {
    final row = [
      item.category ?? '',
      item.key,
      item.description ?? '',
      item.placeholders ?? '',
      ...data.languages.map((e) => item.translations[e] ?? '')
    ];
    sheet.appendRow(row);
  }
  // 隐藏第 4 列
  sheet.setColWidth(3, 0);
  final bytes = excel.save();
  if (bytes == null) {
    stdout.write('''
        Error occurred while saving the excel file.\n
        Do you have the necessary permissions?
        ''');
    return;
  }
  File output = File(filename);
  if(!output.existsSync()){
    output.createSync(recursive: true);
  }
  output.writeAsBytesSync(bytes);
}
