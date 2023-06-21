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
    newCommand.addOption('input',abbr:'i',help:'Input file or directory');
    newCommand.addOption('output',abbr:'o',help:'Output directory');
    newCommand.addOption('default',abbr:'d',help:'Default language',defaultsTo: 'en');
  }
  // parse.addOption(
  //   'out',
  //   abbr: 'o',
  //   help: 'Specify the output directory',
  // );

  final flags = parser.parse(args);
  switch (flags.command?.name) {
    case 'new':
      _handleNew(flags.command!);
      return;
    case 'excel':
      _handleExcel(flags.command!);
      return;
    case 'arb':
      _handleArb(flags.command!);
      return;
  }

  _usage(parser);
  exit(1);
}

void _handleNew(ArgResults command) {
  final defOut = path.join(Directory.current.path, 'template.xlsx');
  final out = command['out'] ?? defOut;
  stdout.writeln('Create new Excel file for translation: $out');
  newTemplate(out);
  exit(0);
}

void _handleExcel(ArgResults command) {
  final input = command['input'];
  final output = command['output'] ??
      path.join(
        Directory.current.path,
        '${path.withoutExtension(input)}l10n.xlsx',
      );
  stdout.writeln('Generate Excel from: $input');
  final data = parseARB(input);
  writeExcel(output, data);
  exit(0);
}

void _handleArb(ArgResults command) {
  final input = command['input'];
  final output = command['output'] ??
      path.join(
        Directory.current.path,
        '${path.basenameWithoutExtension(input)}.arb',
      );
  final String isDefault = command['default'];
  stdout.writeln('Generate ARB from: $input');
  final data = parseExcel(filename: input);
  writeARB(output, data,isDefault);
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
