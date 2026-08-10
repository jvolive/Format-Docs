// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:format_docs/features/remove_text_formatting/utils/text_unformatter.dart';
import 'package:format_docs/features/review_html/utils/paste_helper.dart';

class RemoveTextFormattingScreen extends StatefulWidget {
  const RemoveTextFormattingScreen({super.key});

  static const routeName = '/remove-text-formatting';

  @override
  State<RemoveTextFormattingScreen> createState() =>
      _RemoveTextFormattingScreenState();
}

class _RemoveTextFormattingScreenState
    extends State<RemoveTextFormattingScreen> {
  late final TextEditingController _inputController;
  late final TextEditingController _outputController;
  late final FocusNode _inputFocusNode;
  late final VoidCallback _removePasteInterceptor;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _outputController = TextEditingController();
    _inputFocusNode = FocusNode();
    _inputController.addListener(_syncOutput);
    _removePasteInterceptor = interceptClipboardPaste(
      canHandlePaste: () => _inputFocusNode.hasFocus,
      onPasted: _onClipboardPasted,
    );
  }

  @override
  void dispose() {
    _removePasteInterceptor();
    _inputController.removeListener(_syncOutput);
    _inputFocusNode.dispose();
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  void _onClipboardPasted(String clipboardContent, {required bool isHtml}) {
    final cleanedText = removeFormattingFromText(
      clipboardContent,
      isHtml: isHtml,
    );
    _insertTextAtCursor(cleanedText);
    _syncOutput();
  }

  void _insertTextAtCursor(String textToInsert) {
    final currentValue = _inputController.value;
    final selection = currentValue.selection;

    if (!selection.isValid) {
      _inputController.text = textToInsert;
      return;
    }

    final currentText = currentValue.text;
    final safeStart = selection.start.clamp(0, currentText.length);
    final safeEnd = selection.end.clamp(0, currentText.length);
    final nextText = currentText.replaceRange(safeStart, safeEnd, textToInsert);
    final nextOffset = safeStart + textToInsert.length;

    _inputController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
  }

  void _syncOutput() {
    final cleaned = removeFormattingFromText(_inputController.text);
    if (_outputController.text == cleaned) return;

    _outputController.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
      composing: TextRange.empty,
    );
    setState(() {});
  }

  void _clearAll() {
    _inputController.clear();
    _outputController.clear();
    setState(() {});
  }

  Future<void> _copyOutput() async {
    final text = _outputController.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há texto para copiar.')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Texto copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final hasOutput = _outputController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Remover formatação do texto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cole o texto no campo abaixo para converter para texto simples.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Ideal para remover estilos vindos do Word, e-mail ou páginas web.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    minLines: 8,
                    maxLines: 14,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Cole aqui o texto com formatação...',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _syncOutput,
                        icon: const Icon(Icons.format_clear_rounded),
                        label: const Text('Remover formatação'),
                      ),
                      OutlinedButton(
                        onPressed: _clearAll,
                        child: const Text('Limpar tudo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Texto sem formatação',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: hasOutput ? _copyOutput : null,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _outputController,
                    readOnly: true,
                    minLines: 8,
                    maxLines: 14,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'O texto limpo aparece aqui...',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerLow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
