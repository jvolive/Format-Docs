// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:format_docs/initializer.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_docs/view_model/review_docs_view_model.dart';

class ReviewDocsScreen extends StatefulWidget {
  const ReviewDocsScreen({super.key});

  static const routeName = '/review';

  @override
  State<ReviewDocsScreen> createState() => _ReviewDocsScreenState();
}

class _ReviewDocsScreenState extends State<ReviewDocsScreen> {
  late final ReviewDocsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<ReviewDocsViewModel>();
  }

  Future<void> _pickAndReviewDocument() async {
    try {
      final picked = await _pickDocxFile();
      if (picked == null || !mounted) return;

      await _viewModel.reviewDocument(
        fileName: picked.fileName,
        fileBytes: picked.fileBytes,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<_PickedDocx?> _pickDocxFile() async {
    final input =
        html.FileUploadInputElement()
          ..accept = '.docx'
          ..multiple = false;

    input.click();
    await input.onChange.first;

    final file = input.files?.first;
    if (file == null) return null;

    final bytes = await _readFileAsBytes(file);
    return _PickedDocx(fileName: file.name, fileBytes: bytes);
  }

  Future<Uint8List> _readFileAsBytes(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Não foi possível ler o arquivo.'));
      }
    });

    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;

      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }
      if (result is Uint8List) {
        completer.complete(result);
        return;
      }

      completer.completeError(Exception('Formato de arquivo inválido.'));
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  void _downloadFixedDocument(ReviewResult result) {
    final bytes = base64Decode(result.fixedDocxBase64);
    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute('download', result.fixedFilename)
          ..click();

    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar documento')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          final result = _viewModel.result;

          return ListView(
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
                        'Envie um arquivo .docx para revisar com suas regras.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed:
                                _viewModel.isLoading
                                    ? null
                                    : _pickAndReviewDocument,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Selecionar .docx'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed:
                                _viewModel.isLoading ? null : _viewModel.clear,
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _viewModel.fileName != null
                            ? 'Arquivo: ${_viewModel.fileName}'
                            : 'Nenhum arquivo selecionado.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_viewModel.isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_viewModel.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBox(message: _viewModel.errorMessage!),
              ],
              if (result != null) ...[
                const SizedBox(height: 14),
                _SummaryCard(summary: result.summary),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _downloadFixedDocument(result),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Baixar .docx corrigido'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Problemas encontrados (${result.issues.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (result.issues.isEmpty)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nenhum problema encontrado para as regras atuais.',
                      ),
                    ),
                  ),
                ...result.issues.map((issue) => _IssueCard(issue: issue)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ReviewSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
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
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Total: ${summary.totalIssues}'),
            _chip('Formatação: ${summary.formattingTrigger}'),
            _chip('Substituição: ${summary.wordSubstitution}'),
            _chip('Símbolo §: ${summary.paragraphSymbol}'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(label: Text(label));
  }
}

class _IssueCard extends StatelessWidget {
  final ReviewIssue issue;

  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titleForType(issue.type),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Parágrafo #${issue.paragraphIndex + 1}'),
            const SizedBox(height: 4),
            Text('Encontrado: ${issue.found}'),
            const SizedBox(height: 4),
            Text('Esperado: ${issue.expected}'),
            if (issue.paragraphText.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                issue.paragraphText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(
                    issue.autoFixable ? 'Auto-corrigível' : 'Somente relatório',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleForType(ReviewIssueType type) {
    switch (type) {
      case ReviewIssueType.formattingTrigger:
        return 'Gatilho de formatação';
      case ReviewIssueType.wordSubstitution:
        return 'Substituição de termo';
      case ReviewIssueType.paragraphSymbol:
        return 'Validação de símbolo §';
    }
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

class _PickedDocx {
  final String fileName;
  final Uint8List fileBytes;

  const _PickedDocx({required this.fileName, required this.fileBytes});
}
