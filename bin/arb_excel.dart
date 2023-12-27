import 'dart:io';

import 'package:arb_excel/arb_excel.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

const _kVersion = '0.0.1';

const _kCommands = {
  'new': 'New translation sheet',
  'excel': 'Import ARB files to sheet',
  'arb': 'Export to ARB files',
};

void main(List<String> args) {
  final parser = ArgParser();
  // parse.addOption('new', abbr: 'n', help: 'Create new Excel template');
  // parse.addOption('excel', abbr: 'e', help: 'Import ARB files to sheet');
  // parse.addOption('arb', abbr: 'a', help: 'Export to ARB files');
  // parse.addOption('out', abbr: 'o', help: 'Specify the output directory');
  for (var command in _kCommands.keys) {
    final newCommand = parser.addCommand(command);
    newCommand.addOption(
      'input',
      abbr: 'i',
      help: 'Input file or directory',
    );
    newCommand.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory',
    );
    newCommand.addOption(
      'default',
      abbr: 'd',
      help: 'Default language',
      defaultsTo: 'en',
    );
  }

  final flags = parser.parse(args);
  switch (flags.command?.name) {
    case 'new':
      _handleExportTemplateExcel(flags.command!);
      return;
    case 'excel':
      _handleExportExcel(flags.command!);
      return;
    case 'arb':
      _handleExportArb(flags.command!);
      return;
  }

  _usage(parser);
  exit(1);
}

/// 处理导出 Excel 模板
void _handleExportTemplateExcel(ArgResults command) {
  final defOut = path.join(Directory.current.path, 'template.xlsx');
  final out = command['out'] ?? defOut;
  stdout.writeln('Create new Excel file for translation: $out');
  newTemplate(out);
  exit(0);
}

/// 处理导出 Excel
void _handleExportExcel(ArgResults command) {
  final input = command['input'];
  final output = command['output'] ??
      path.join(
        Directory.current.path,
        '${path.withoutExtension(input)}l10n.xlsx',
      );
  // 默认语言
  final String defaultLanguage = command['default'];
  stdout.writeln('Generate Excel from: $input');
  final data = parseARB(input, defaultLanguage);
  writeExcel(output, data);
  exit(0);
}

/// 处理导出 arb
void _handleExportArb(ArgResults command) {
  final input = command['input'];
  final output = command['output'] ??
      path.join(
        Directory.current.path,
        '${path.basenameWithoutExtension(input)}.arb',
      );
  // 默认语言
  final String defaultLanguage = command['default'];
  stdout.writeln('Generate ARB from: $input');
  final data = parseExcel(filename: input);
  writeARB(output, data, defaultLanguage);
  exit(0);
}

void _usage(ArgParser parse) {
  stdout.writeln('arb_sheet v$_kVersion\n');
  stdout.writeln(
    '  arb_sheet excel -i path/to/arbs/ -o path/to/output/l10n.xlsx\n',
  );
  stdout.writeln('USAGE: arb_sheet <command> [arguments]\n');
  stdout.writeln('Global options:');
  stdout.writeln(parse.usage);
  stdout.writeln();
  stdout.writeln('Available commands:');
  _kCommands.forEach((command, des) {
    stdout.writeln('  $command\t\t$des');
  });
}
