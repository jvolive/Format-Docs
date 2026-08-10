// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

final RegExp _spaceGroupPattern = RegExp(r'[ \t\f\v]+');
final RegExp _blankLineGroupPattern = RegExp(r'\n{3,}');

String removeFormattingFromText(String input, {bool isHtml = false}) {
  if (input.isEmpty) return '';

  final normalizedLineBreaks = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  final plainText =
      isHtml ? _htmlToPlainText(normalizedLineBreaks) : normalizedLineBreaks;

  return _normalizePlainText(plainText);
}

String _htmlToPlainText(String htmlContent) {
  final htmlWithLineHints = htmlContent
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|li|tr|h[1-6]|blockquote|pre)>', caseSensitive: false),
        '\n',
      );

  final container =
      html.DivElement()..setInnerHtml(
        htmlWithLineHints,
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );

  return container.innerText;
}

String _normalizePlainText(String text) {
  final normalizedSpaces = text.replaceAll('\u00A0', ' ');
  final normalizedLines =
      normalizedSpaces
          .split('\n')
          .map((line) => line.replaceAll(_spaceGroupPattern, ' ').trimRight())
          .join('\n')
          .trim();

  return normalizedLines.replaceAll(_blankLineGroupPattern, '\n\n');
}
