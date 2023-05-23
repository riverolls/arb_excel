import 'dart:io';

import 'package:arb_excel/arb_excel.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

const _kVersion = '0.0.1';

void main(List<String> args) {
  final parse = ArgParser();
  parse.addFlag(
    'new',
    abbr: 'n',
    help: 'New translation sheet',
  );
  parse.addOption(
    'arb',
    abbr: 'a',
    help: 'Export to ARB files',
  );
  parse.addOption(
    'excel',
    abbr: 'e',
    help: 'Import ARB files to sheet',
  );
  parse.addOption(
    'out',
    abbr: 'o',
    help: 'Specify the output directory',
  );
  final flags = parse.parse(args);

  if (flags.wasParsed('new')) {
    final defOut = path.join(Directory.current.path, 'template.xlsx');
    final out = flags['out'] ?? defOut;
    stdout.writeln('Create new Excel file for translation: $out');
    newTemplate(out);
    exit(0);
  }
  if (flags.wasParsed('arb')) {
    final input = flags['arb'];
    final output = flags['out'] ??
        path.join(
          Directory.current.path,
          '${path.basenameWithoutExtension(input)}.arb',
        );
    stdout.writeln('Generate ARB from: $input');
    final data = parseExcel(filename: input);
    writeARB(output, data);
    exit(0);
  }

  if (flags.wasParsed('excel')) {
    final input = flags['excel'];
    final output = flags['out'] ??
        path.join(
          Directory.current.path,
          '${path.withoutExtension(input)}.xlsx',
        );
    stdout.writeln('Generate Excel from: $input');
    final data = parseARB(input);
    writeExcel(output, data);
    exit(0);
  }

  usage(parse);
  exit(1);
}

void usage(ArgParser parse) {
  stdout.writeln('arb_sheet v$_kVersion\n');
  stdout.writeln('USAGE:');
  stdout.writeln(
    '  arb_sheet [OPTIONS] path/to/file/name\n',
  );
  stdout.writeln('OPTIONS');
  stdout.writeln(parse.usage);
}
