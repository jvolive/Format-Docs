// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

typedef HtmlPastePredicate = bool Function();

/// Intercepta paste global e, quando permitido, entrega o conteúdo HTML bruto.
///
/// Retorna uma função de cleanup que remove o listener registrado.
void Function() interceptHtmlPaste({
  required HtmlPastePredicate canHandlePaste,
  required void Function(String htmlContent) onHtmlPasted,
}) {
  void listener(html.Event event) {
    if (!canHandlePaste()) return;

    final pasteEvent = event as html.ClipboardEvent;
    final clipboardData = pasteEvent.clipboardData;
    if (clipboardData == null) return;

    final htmlContent = clipboardData.getData('text/html');
    if (htmlContent.isEmpty) return;

    pasteEvent.preventDefault();
    onHtmlPasted(htmlContent);
  }

  html.document.addEventListener('paste', listener);

  return () {
    html.document.removeEventListener('paste', listener);
  };
}
