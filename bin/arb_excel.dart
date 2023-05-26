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
  final parse = ArgParser();
  for (var command in _kCommands.keys) {
    parse.addCommand(command);
  }
  parse.addOption(
    'out',
    abbr: 'o',
    help: 'Specify the output directory',
  );

  final flags = parse.parse(args);

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

  _usage(parse);
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
  final input = command['excel'];
  final output = command['out'] ??
      path.join(
        Directory.current.path,
        '${path.withoutExtension(input)}.xlsx',
      );
  stdout.writeln('Generate Excel from: $input');
  final data = parseARB(input);
  writeExcel(output, data);
  exit(0);
}

void _handleArb(ArgResults command) {
  final input = command['arb'];
  final output = command['out'] ??
      path.join(
        Directory.current.path,
        '${path.basenameWithoutExtension(input)}.arb',
      );
  stdout.writeln('Generate ARB from: $input');
  final data = parseExcel(filename: input);
  writeARB(output, data);
  exit(0);
}

void _usage(ArgParser parse) {
  stdout.writeln('arb_sheet v$_kVersion\n');
  stdout.writeln(
    '  arb_sheet excel path/to/l10n/ -o path/to/output/l10n.xlsx\n',
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
