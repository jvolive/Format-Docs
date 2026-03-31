// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:format_docs/initializer.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_docs/view_model/review_docs_view_model.dart';
import 'package:format_docs/features/review_html/utils/paste_helper.dart';

class ReviewDocsScreen extends StatefulWidget {
  const ReviewDocsScreen({super.key});

  static const routeName = '/review';

  @override
  State<ReviewDocsScreen> createState() => _ReviewDocsScreenState();
}

enum _IssueLayoutMode { columns, rows }

class _ReviewDocsScreenState extends State<ReviewDocsScreen> {
  static const String _acceptedFileExtensions = '.doc,.docx,.html';

  late final ReviewDocsViewModel _viewModel;
  late final TextEditingController _htmlController;
  late final FocusNode _htmlFocusNode;
  late final VoidCallback _removePasteInterceptor;
  _IssueLayoutMode _issueLayoutMode = _IssueLayoutMode.columns;
  final Set<ReviewIssueType> _activeFilters = {...ReviewIssueType.values};

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<ReviewDocsViewModel>();
    _htmlController = TextEditingController();
    _htmlFocusNode = FocusNode();
    _removePasteInterceptor = interceptHtmlPaste(
      canHandlePaste: () => _htmlFocusNode.hasFocus,
      onHtmlPasted: _insertPastedHtml,
    );
  }

  @override
  void dispose() {
    _removePasteInterceptor();
    _htmlFocusNode.dispose();
    _htmlController.dispose();
    super.dispose();
  }

  void _insertPastedHtml(String htmlContent) {
    final currentValue = _htmlController.value;
    final selection = currentValue.selection;

    if (!selection.isValid) {
      _htmlController.text = htmlContent;
      return;
    }

    final text = currentValue.text;
    final safeStart = selection.start.clamp(0, text.length);
    final safeEnd = selection.end.clamp(0, text.length);

    final newText = text.replaceRange(safeStart, safeEnd, htmlContent);
    final newOffset = safeStart + htmlContent.length;

    _htmlController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
      composing: TextRange.empty,
    );
  }

  Future<void> _pickAndReviewDocument() async {
    try {
      final picked = await _pickSupportedFile();
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

  Future<void> _reviewHtmlContent() async {
    final htmlContent = _htmlController.text.trim();
    if (htmlContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cole o HTML para iniciar a revisão.')),
      );
      return;
    }

    try {
      await _viewModel.reviewDocument(
        fileName: 'conteudo.html',
        fileBytes: Uint8List.fromList(utf8.encode(htmlContent)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<_PickedReviewFile?> _pickSupportedFile() async {
    final input =
        html.FileUploadInputElement()
          ..accept = _acceptedFileExtensions
          ..multiple = false;

    input.click();
    await input.onChange.first;

    final file = input.files?.first;
    if (file == null) return null;
    if (!_isSupportedFileName(file.name)) {
      throw Exception(
        'Formato inválido. Envie um arquivo .doc, .docx ou .html.',
      );
    }

    final bytes = await _readFileAsBytes(file);
    return _PickedReviewFile(fileName: file.name, fileBytes: bytes);
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

  bool _isSupportedFileName(String fileName) {
    final normalized = fileName.toLowerCase();
    return normalized.endsWith('.doc') ||
        normalized.endsWith('.docx') ||
        normalized.endsWith('.html');
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
                        'Envie um arquivo .doc, .docx ou .html para revisar com suas regras.',
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
                            label: const Text('Selecionar arquivo'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _viewModel.isLoading ? null : _clearAll,
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
                      Text(
                        'Revisão por HTML (colar texto)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cole seu HTML no campo abaixo e clique em "Revisar HTML colado".',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _htmlController,
                        focusNode: _htmlFocusNode,
                        enabled: !_viewModel.isLoading,
                        minLines: 8,
                        maxLines: 14,
                        style: const TextStyle(fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'Digite aqui seu texto...',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed:
                              _viewModel.isLoading ? null : _reviewHtmlContent,
                          icon: const Icon(Icons.code_rounded),
                          label: const Text('Revisar HTML colado'),
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
                _SummaryCard(
                  summary: result.summary,
                  activeFilters: _activeFilters,
                  onToggleFilter: _toggleFilter,
                ),
                const SizedBox(height: 14),
                _IssuesByCategory(
                  totalIssues: result.issues.length,
                  issueBuckets: _viewModel.issueBuckets,
                  layoutMode: _issueLayoutMode,
                  activeFilters: _activeFilters,
                  onLayoutModeChanged: (mode) {
                    if (_issueLayoutMode == mode) return;
                    setState(() => _issueLayoutMode = mode);
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _activeFilters
        ..clear()
        ..addAll(ReviewIssueType.values);
    });
    _htmlController.clear();
    _viewModel.clear();
  }

  void _toggleFilter(ReviewIssueType issueType) {
    setState(() {
      if (_activeFilters.contains(issueType)) {
        if (_activeFilters.length == 1) return;
        _activeFilters.remove(issueType);
        return;
      }

      _activeFilters.add(issueType);
    });
  }
}

class _SummaryCard extends StatelessWidget {
  final ReviewSummary summary;
  final Set<ReviewIssueType> activeFilters;
  final ValueChanged<ReviewIssueType> onToggleFilter;

  const _SummaryCard({
    required this.summary,
    required this.activeFilters,
    required this.onToggleFilter,
  });

  @override
  Widget build(BuildContext context) {
    final filterItems = [
      (
        type: ReviewIssueType.formattingTrigger,
        label: 'Formatação',
        count: summary.formattingTrigger,
      ),
      (
        type: ReviewIssueType.wordSubstitution,
        label: 'Substituição',
        count: summary.wordSubstitution,
      ),
      (
        type: ReviewIssueType.paragraphSymbol,
        label: 'Símbolo §',
        count: summary.paragraphSymbol,
      ),
    ];

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: ${summary.totalIssues}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  filterItems.map((item) {
                    final isSelected = activeFilters.contains(item.type);
                    return FilterChip(
                      selected: isSelected,
                      label: Text('${item.label}: ${item.count}'),
                      onSelected: (_) => onToggleFilter(item.type),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssuesByCategory extends StatelessWidget {
  final int totalIssues;
  final ReviewIssueBuckets issueBuckets;
  final _IssueLayoutMode layoutMode;
  final Set<ReviewIssueType> activeFilters;
  final ValueChanged<_IssueLayoutMode> onLayoutModeChanged;

  const _IssuesByCategory({
    required this.totalIssues,
    required this.issueBuckets,
    required this.layoutMode,
    required this.activeFilters,
    required this.onLayoutModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <_IssueCategoryColumnData>[
      if (activeFilters.contains(ReviewIssueType.formattingTrigger))
        _IssueCategoryColumnData(
          id: 'formatting',
          title: 'Formatação',
          icon: Icons.format_italic_rounded,
          issues: issueBuckets.formatting,
        ),
      if (activeFilters.contains(ReviewIssueType.wordSubstitution))
        _IssueCategoryColumnData(
          id: 'substitution',
          title: 'Substituição',
          icon: Icons.find_replace_rounded,
          issues: issueBuckets.substitutions,
        ),
      if (activeFilters.contains(ReviewIssueType.paragraphSymbol))
        _IssueCategoryColumnData(
          id: 'symbol',
          title: 'Símbolo §',
          icon: Icons.rule_rounded,
          issues: issueBuckets.symbols,
        ),
    ];

    final filteredTotalIssues = categories.fold<int>(
      0,
      (sum, item) => sum + item.issues.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(
              'Problemas encontrados ($filteredTotalIssues de $totalIssues)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            SegmentedButton<_IssueLayoutMode>(
              segments: const [
                ButtonSegment<_IssueLayoutMode>(
                  value: _IssueLayoutMode.columns,
                  icon: Icon(Icons.view_week_rounded),
                  label: Text('Colunas'),
                ),
                ButtonSegment<_IssueLayoutMode>(
                  value: _IssueLayoutMode.rows,
                  icon: Icon(Icons.view_agenda_rounded),
                  label: Text('Linhas'),
                ),
              ],
              selected: {layoutMode},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                onLayoutModeChanged(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (totalIssues == 0)
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
              child: Text('Nenhum problema encontrado para as regras atuais.'),
            ),
          )
        else
          layoutMode == _IssueLayoutMode.columns
              ? _ColumnsIssuesLayout(categories: categories)
              : _RowsIssuesLayout(categories: categories),
      ],
    );
  }
}

class _IssueCategoryColumnData {
  final String id;
  final String title;
  final IconData icon;
  final List<ReviewIssue> issues;

  const _IssueCategoryColumnData({
    required this.id,
    required this.title,
    required this.icon,
    required this.issues,
  });
}

class _IssueCategoryColumn extends StatelessWidget {
  final _IssueCategoryColumnData data;

  const _IssueCategoryColumn({required this.data});

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  data.icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(label: Text('${data.issues.length}')),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  data.issues.isEmpty
                      ? Center(
                        child: Text(
                          'Nenhum item nesta categoria.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                      : ListView.separated(
                        key: PageStorageKey<String>('issues-${data.id}'),
                        itemBuilder: (context, index) {
                          return _IssueCard(
                            issue: data.issues[index],
                            margin: EdgeInsets.zero,
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemCount: data.issues.length,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnsIssuesLayout extends StatelessWidget {
  final List<_IssueCategoryColumnData> categories;

  const _ColumnsIssuesLayout({required this.categories});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return SizedBox(
            height: 620,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _IssueCategoryColumn(data: categories[i])),
                ],
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < categories.length; i++) ...[
              SizedBox(
                height: 340,
                child: _IssueCategoryColumn(data: categories[i]),
              ),
              if (i < categories.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _RowsIssuesLayout extends StatelessWidget {
  final List<_IssueCategoryColumnData> categories;

  const _RowsIssuesLayout({required this.categories});

  @override
  Widget build(BuildContext context) {
    final rowItems = _buildRows(categories);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth >= 1100 ? 680.0 : 560.0;

        return SizedBox(
          height: height,
          child: ListView.separated(
            key: const PageStorageKey<String>('issues-rows-layout'),
            itemBuilder: (context, index) {
              final item = rowItems[index];

              if (item.category != null) {
                return _IssueRowCategoryHeader(category: item.category!);
              }

              return _IssueCard(issue: item.issue!, margin: EdgeInsets.zero);
            },
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: rowItems.length,
          ),
        );
      },
    );
  }

  List<_IssueRowItem> _buildRows(List<_IssueCategoryColumnData> categories) {
    final result = <_IssueRowItem>[];

    for (final category in categories) {
      result.add(_IssueRowItem.category(category));
      for (final issue in category.issues) {
        result.add(_IssueRowItem.issue(issue));
      }
    }

    return result;
  }
}

class _IssueRowItem {
  final _IssueCategoryColumnData? category;
  final ReviewIssue? issue;

  const _IssueRowItem._({this.category, this.issue});

  factory _IssueRowItem.category(_IssueCategoryColumnData value) {
    return _IssueRowItem._(category: value);
  }

  factory _IssueRowItem.issue(ReviewIssue value) {
    return _IssueRowItem._(issue: value);
  }
}

class _IssueRowCategoryHeader extends StatelessWidget {
  final _IssueCategoryColumnData category;

  const _IssueRowCategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              category.icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Chip(label: Text('${category.issues.length}')),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final ReviewIssue issue;
  final EdgeInsetsGeometry margin;

  const _IssueCard({
    required this.issue,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: margin,
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
            _CopyableIssueField(label: 'Encontrado', value: issue.found),
            const SizedBox(height: 4),
            _CopyableIssueField(label: 'Esperado', value: issue.expected),
            if (issue.paragraphText.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _CopyableIssueField(
                label: 'Trecho',
                value: issue.paragraphText,
                dense: false,
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

class _CopyableIssueField extends StatelessWidget {
  final String label;
  final String value;
  final bool dense;

  const _CopyableIssueField({
    required this.label,
    required this.value,
    this.dense = true,
  });

  static const int _densePreviewLimit = 180;
  static const int _expandedPreviewLimit = 900;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = value.trim();
    final previewLimit = dense ? _densePreviewLimit : _expandedPreviewLimit;
    final hasText = effectiveValue.isNotEmpty;
    final isPreviewTruncated = hasText && effectiveValue.length > previewLimit;
    final previewText =
        isPreviewTruncated
            ? '${effectiveValue.substring(0, previewLimit)}…'
            : effectiveValue;

    return Container(
      padding:
          dense
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration:
          dense
              ? null
              : BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                if (dense)
                  Text(
                    hasText ? previewText : '-',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )
                else
                  SelectableText(
                    hasText ? previewText : '-',
                    maxLines: 8,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (isPreviewTruncated) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Prévia reduzida para manter a performance. Use copiar para obter o texto completo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar $label',
            onPressed:
                effectiveValue.isEmpty
                    ? null
                    : () => _copyToClipboard(context, label, effectiveValue),
            icon: const Icon(Icons.copy_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String label,
    String text,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado para a área de transferência.')),
    );
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

class _PickedReviewFile {
  final String fileName;
  final Uint8List fileBytes;

  const _PickedReviewFile({required this.fileName, required this.fileBytes});
}
