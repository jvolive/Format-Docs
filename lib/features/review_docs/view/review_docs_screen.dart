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
import 'package:format_docs/features/rules/repository/rules_repository.dart';
import 'package:format_docs/features/review_html/utils/paste_helper.dart';

class ReviewDocsScreen extends StatefulWidget {
  const ReviewDocsScreen({super.key});

  static const routeName = '/review';

  @override
  State<ReviewDocsScreen> createState() => _ReviewDocsScreenState();
}

enum _IssueLayoutMode { columns, rows }

const String _emptyRuleFilterKey = '__empty_rule__';

class _RuleFilterItem {
  final String key;
  final int count;
  final String fullLabel;
  final String shortLabel;

  const _RuleFilterItem({
    required this.key,
    required this.count,
    required this.fullLabel,
    required this.shortLabel,
  });
}

String _ruleFilterKeyFromIssue(ReviewIssue issue) {
  final raw = issue.ruleId.trim();
  if (raw.isEmpty) return _emptyRuleFilterKey;
  return raw;
}

String _ruleDisplayNameFromIssueWithFallback(
  ReviewIssue issue, {
  String? fallbackRuleName,
}) {
  final ruleName = issue.ruleName.trim();
  if (ruleName.isNotEmpty) return ruleName;

  final mappedName = fallbackRuleName?.trim() ?? '';
  if (mappedName.isNotEmpty) return mappedName;

  final ruleId = issue.ruleId.trim();
  if (ruleId.isNotEmpty) return ruleId;

  return 'Sem regra';
}

String _defaultRuleDisplayName(String ruleKey) {
  if (ruleKey == _emptyRuleFilterKey) return 'Sem regra';
  return ruleKey;
}

String _compactRuleFilterLabel(String displayName) {
  if (displayName.length <= 24) return displayName;
  return '${displayName.substring(0, 21)}...';
}

class _ReviewDocsScreenState extends State<ReviewDocsScreen> {
  static const String _acceptedFileExtensions = '.doc,.docx,.html';

  late final ReviewDocsViewModel _viewModel;
  late final TextEditingController _htmlController;
  late final FocusNode _htmlFocusNode;
  late final VoidCallback _removePasteInterceptor;
  _IssueLayoutMode _issueLayoutMode = _IssueLayoutMode.columns;
  final Set<ReviewIssueType> _activeFilters = {...ReviewIssueType.values};
  final Set<String> _activeRuleFilters = <String>{};
  final Set<ReviewIssue> _reviewedIssues = <ReviewIssue>{};
  final Set<String> _collapsedRowCategoryIds = <String>{};
  final Map<String, String> _ruleNamesById = <String, String>{};
  ReviewResult? _syncedRuleFiltersResult;
  ReviewResult? _syncedReviewedIssuesResult;
  bool _isResolvingRuleNames = false;
  bool _ruleNamesResolutionScheduled = false;

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
      await _ensureRuleNamesLoadedForCurrentResult();
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
      await _ensureRuleNamesLoadedForCurrentResult();
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
          final ruleFilters = _buildRuleFilters(result?.issues ?? const []);
          _syncRuleFiltersForResult(result, ruleFilters);
          _syncReviewedIssuesForResult(result);
          _scheduleRuleNameResolutionIfNeeded(result);

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
                  reviewedIssuesCount: _reviewedIssues.length,
                  activeFilters: _activeFilters,
                  onToggleFilter: _toggleFilter,
                  ruleFilters: ruleFilters,
                  activeRuleFilters: _activeRuleFilters,
                  onToggleRuleFilter: _toggleRuleFilter,
                ),
                const SizedBox(height: 14),
                _IssuesByCategory(
                  totalIssues: result.issues.length,
                  issueBuckets: _viewModel.issueBuckets,
                  layoutMode: _issueLayoutMode,
                  activeFilters: _activeFilters,
                  activeRuleFilters: _activeRuleFilters,
                  isIssueReviewed: _isIssueReviewed,
                  onToggleIssueReviewed: _toggleIssueReviewed,
                  collapsedRowCategoryIds: _collapsedRowCategoryIds,
                  onToggleRowCategoryCollapse: _toggleRowCategoryCollapse,
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
      _activeRuleFilters.clear();
      _reviewedIssues.clear();
      _collapsedRowCategoryIds.clear();
      _ruleNamesById.clear();
      _syncedRuleFiltersResult = null;
      _syncedReviewedIssuesResult = null;
      _isResolvingRuleNames = false;
      _ruleNamesResolutionScheduled = false;
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

  void _toggleRowCategoryCollapse(String categoryId) {
    setState(() {
      if (_collapsedRowCategoryIds.contains(categoryId)) {
        _collapsedRowCategoryIds.remove(categoryId);
        return;
      }

      _collapsedRowCategoryIds.add(categoryId);
    });
  }

  void _toggleRuleFilter(String ruleKey) {
    setState(() {
      if (_activeRuleFilters.contains(ruleKey)) {
        if (_activeRuleFilters.length == 1) return;
        _activeRuleFilters.remove(ruleKey);
        return;
      }

      _activeRuleFilters.add(ruleKey);
    });
  }

  void _syncRuleFiltersForResult(
    ReviewResult? result,
    List<_RuleFilterItem> ruleFilters,
  ) {
    if (result == null) {
      _syncedRuleFiltersResult = null;
      _activeRuleFilters.clear();
      return;
    }

    final availableRuleKeys = ruleFilters.map((item) => item.key).toSet();

    if (!identical(_syncedRuleFiltersResult, result)) {
      _syncedRuleFiltersResult = result;
      _activeRuleFilters
        ..clear()
        ..addAll(availableRuleKeys);
      return;
    }

    _activeRuleFilters.removeWhere((key) => !availableRuleKeys.contains(key));
    if (_activeRuleFilters.isEmpty && availableRuleKeys.isNotEmpty) {
      _activeRuleFilters.addAll(availableRuleKeys);
    }
  }

  void _syncReviewedIssuesForResult(ReviewResult? result) {
    if (result == null) {
      _syncedReviewedIssuesResult = null;
      _reviewedIssues.clear();
      return;
    }

    if (!identical(_syncedReviewedIssuesResult, result)) {
      _syncedReviewedIssuesResult = result;
      _reviewedIssues.clear();
    }
  }

  bool _isIssueReviewed(ReviewIssue issue) {
    return _reviewedIssues.contains(issue);
  }

  void _toggleIssueReviewed(ReviewIssue issue) {
    setState(() {
      if (_reviewedIssues.contains(issue)) {
        _reviewedIssues.remove(issue);
        return;
      }
      _reviewedIssues.add(issue);
    });
  }

  List<_RuleFilterItem> _buildRuleFilters(List<ReviewIssue> issues) {
    if (issues.isEmpty) return const <_RuleFilterItem>[];

    final counts = <String, int>{};
    final displayNamesByRuleKey = <String, String>{};

    for (final issue in issues) {
      final key = _ruleFilterKeyFromIssue(issue);
      counts.update(key, (current) => current + 1, ifAbsent: () => 1);

      final fallbackRuleName = _ruleNamesById[issue.ruleId.trim()];
      final candidateDisplayName = _ruleDisplayNameFromIssueWithFallback(
        issue,
        fallbackRuleName: fallbackRuleName,
      );
      final currentDisplayName = displayNamesByRuleKey[key];
      if (currentDisplayName == null || currentDisplayName == key) {
        displayNamesByRuleKey[key] = candidateDisplayName;
      }
    }

    final entries =
        counts.entries.toList()..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          if (byCount != 0) return byCount;
          return a.key.compareTo(b.key);
        });

    return List<_RuleFilterItem>.unmodifiable(
      entries.map(
        (entry) => _RuleFilterItem(
          key: entry.key,
          count: entry.value,
          fullLabel:
              displayNamesByRuleKey[entry.key] ??
              _defaultRuleDisplayName(entry.key),
          shortLabel: _compactRuleFilterLabel(
            displayNamesByRuleKey[entry.key] ??
                _defaultRuleDisplayName(entry.key),
          ),
        ),
      ),
    );
  }

  Future<void> _ensureRuleNamesLoadedForCurrentResult() async {
    if (_isResolvingRuleNames) return;

    final result = _viewModel.result;
    if (result == null) return;

    final unresolvedRuleIds =
        result.issues
            .map((issue) => issue.ruleId.trim())
            .where((id) => id.isNotEmpty && !_ruleNamesById.containsKey(id))
            .toSet();

    if (unresolvedRuleIds.isEmpty) return;

    _isResolvingRuleNames = true;
    try {
      final rules = await getIt<RulesRepositoryInterface>().fetchRules();
      if (!mounted) return;

      var changed = false;
      for (final rule in rules) {
        final id = rule.id;
        if (id == null || id.trim().isEmpty) continue;

        final name = rule.triggerWord.trim();
        if (name.isEmpty) continue;

        if (_ruleNamesById[id] != name) {
          _ruleNamesById[id] = name;
          changed = true;
        }
      }

      if (changed) {
        setState(() {});
      }
    } catch (_) {
      // Mantém fallback por id quando a busca de regras não estiver disponível.
    } finally {
      _isResolvingRuleNames = false;
    }
  }

  void _scheduleRuleNameResolutionIfNeeded(ReviewResult? result) {
    if (result == null ||
        _isResolvingRuleNames ||
        _ruleNamesResolutionScheduled) {
      return;
    }

    final unresolvedRuleIds =
        result.issues
            .map((issue) => issue.ruleId.trim())
            .where((id) => id.isNotEmpty && !_ruleNamesById.containsKey(id))
            .toSet();

    if (unresolvedRuleIds.isEmpty) return;

    _ruleNamesResolutionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _ruleNamesResolutionScheduled = false;
      if (!mounted) return;
      await _ensureRuleNamesLoadedForCurrentResult();
    });
  }
}

class _SummaryCard extends StatelessWidget {
  final ReviewSummary summary;
  final int reviewedIssuesCount;
  final Set<ReviewIssueType> activeFilters;
  final ValueChanged<ReviewIssueType> onToggleFilter;
  final List<_RuleFilterItem> ruleFilters;
  final Set<String> activeRuleFilters;
  final ValueChanged<String> onToggleRuleFilter;

  const _SummaryCard({
    required this.summary,
    required this.reviewedIssuesCount,
    required this.activeFilters,
    required this.onToggleFilter,
    required this.ruleFilters,
    required this.activeRuleFilters,
    required this.onToggleRuleFilter,
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
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text(
                  'Total: ${summary.totalIssues}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Revisados: $reviewedIssuesCount',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value:
                  summary.totalIssues == 0
                      ? 0
                      : reviewedIssuesCount / summary.totalIssues,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 10),
            Text(
              'Progresso de revisão',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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
            if (ruleFilters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Filtrar por regra',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    ruleFilters.map((item) {
                      final isSelected = activeRuleFilters.contains(item.key);
                      return Tooltip(
                        message: item.fullLabel,
                        child: FilterChip(
                          selected: isSelected,
                          label: Text('${item.shortLabel}: ${item.count}'),
                          onSelected: (_) => onToggleRuleFilter(item.key),
                        ),
                      );
                    }).toList(),
              ),
            ],
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
  final Set<String> activeRuleFilters;
  final bool Function(ReviewIssue) isIssueReviewed;
  final ValueChanged<ReviewIssue> onToggleIssueReviewed;
  final Set<String> collapsedRowCategoryIds;
  final ValueChanged<String> onToggleRowCategoryCollapse;
  final ValueChanged<_IssueLayoutMode> onLayoutModeChanged;

  const _IssuesByCategory({
    required this.totalIssues,
    required this.issueBuckets,
    required this.layoutMode,
    required this.activeFilters,
    required this.activeRuleFilters,
    required this.isIssueReviewed,
    required this.onToggleIssueReviewed,
    required this.collapsedRowCategoryIds,
    required this.onToggleRowCategoryCollapse,
    required this.onLayoutModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <_IssueCategoryColumnData>[
      if (activeFilters.contains(ReviewIssueType.formattingTrigger))
        _buildCategory(
          id: 'formatting',
          title: 'Formatação',
          icon: Icons.format_italic_rounded,
          source: issueBuckets.formatting,
        ),
      if (activeFilters.contains(ReviewIssueType.wordSubstitution))
        _buildCategory(
          id: 'substitution',
          title: 'Substituição',
          icon: Icons.find_replace_rounded,
          source: issueBuckets.substitutions,
        ),
      if (activeFilters.contains(ReviewIssueType.paragraphSymbol))
        _buildCategory(
          id: 'symbol',
          title: 'Símbolo §',
          icon: Icons.rule_rounded,
          source: issueBuckets.symbols,
        ),
    ];

    final filteredTotalIssues = categories.fold<int>(
      0,
      (sum, item) => sum + item.unresolvedIssuesCount,
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
              ? _ColumnsIssuesLayout(
                categories: categories,
                isIssueReviewed: isIssueReviewed,
                onToggleIssueReviewed: onToggleIssueReviewed,
              )
              : _RowsIssuesLayout(
                categories: categories,
                isIssueReviewed: isIssueReviewed,
                onToggleIssueReviewed: onToggleIssueReviewed,
                collapsedCategoryIds: collapsedRowCategoryIds,
                onToggleCategoryCollapse: onToggleRowCategoryCollapse,
              ),
      ],
    );
  }

  List<ReviewIssue> _filterIssuesByRule(List<ReviewIssue> source) {
    if (activeRuleFilters.isEmpty) return const <ReviewIssue>[];

    return source
        .where(
          (issue) => activeRuleFilters.contains(_ruleFilterKeyFromIssue(issue)),
        )
        .toList(growable: false);
  }

  _IssueCategoryColumnData _buildCategory({
    required String id,
    required String title,
    required IconData icon,
    required List<ReviewIssue> source,
  }) {
    final filtered = _filterIssuesByRule(source);
    return _IssueCategoryColumnData(
      id: id,
      title: title,
      icon: icon,
      issues: _orderIssuesByResolved(filtered),
      unresolvedIssuesCount: _countUnresolvedIssues(filtered),
    );
  }

  int _countUnresolvedIssues(List<ReviewIssue> source) {
    var count = 0;
    for (final issue in source) {
      if (!isIssueReviewed(issue)) {
        count++;
      }
    }
    return count;
  }

  List<ReviewIssue> _orderIssuesByResolved(List<ReviewIssue> source) {
    if (source.isEmpty) return const <ReviewIssue>[];

    final unresolved = <ReviewIssue>[];
    final resolved = <ReviewIssue>[];

    for (final issue in source) {
      if (isIssueReviewed(issue)) {
        resolved.add(issue);
        continue;
      }
      unresolved.add(issue);
    }

    return List<ReviewIssue>.unmodifiable(<ReviewIssue>[
      ...unresolved,
      ...resolved,
    ]);
  }
}

class _IssueCategoryColumnData {
  final String id;
  final String title;
  final IconData icon;
  final List<ReviewIssue> issues;
  final int unresolvedIssuesCount;

  const _IssueCategoryColumnData({
    required this.id,
    required this.title,
    required this.icon,
    required this.issues,
    required this.unresolvedIssuesCount,
  });
}

class _IssueCategoryColumn extends StatelessWidget {
  final _IssueCategoryColumnData data;
  final bool Function(ReviewIssue) isIssueReviewed;
  final ValueChanged<ReviewIssue> onToggleIssueReviewed;

  const _IssueCategoryColumn({
    required this.data,
    required this.isIssueReviewed,
    required this.onToggleIssueReviewed,
  });

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
                Chip(label: Text('${data.unresolvedIssuesCount}')),
              ],
            ),
            const SizedBox(height: 8),
            if (data.issues.isEmpty)
              Text(
                'Nenhum item nesta categoria.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < data.issues.length; i++) ...[
                    _IssueCard(
                      issue: data.issues[i],
                      isReviewed: isIssueReviewed(data.issues[i]),
                      onToggleReviewed:
                          () => onToggleIssueReviewed(data.issues[i]),
                      margin: EdgeInsets.zero,
                    ),
                    if (i < data.issues.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ColumnsIssuesLayout extends StatelessWidget {
  final List<_IssueCategoryColumnData> categories;
  final bool Function(ReviewIssue) isIssueReviewed;
  final ValueChanged<ReviewIssue> onToggleIssueReviewed;

  const _ColumnsIssuesLayout({
    required this.categories,
    required this.isIssueReviewed,
    required this.onToggleIssueReviewed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _IssueCategoryColumn(
                    data: categories[i],
                    isIssueReviewed: isIssueReviewed,
                    onToggleIssueReviewed: onToggleIssueReviewed,
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < categories.length; i++) ...[
              _IssueCategoryColumn(
                data: categories[i],
                isIssueReviewed: isIssueReviewed,
                onToggleIssueReviewed: onToggleIssueReviewed,
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
  final bool Function(ReviewIssue) isIssueReviewed;
  final ValueChanged<ReviewIssue> onToggleIssueReviewed;
  final Set<String> collapsedCategoryIds;
  final ValueChanged<String> onToggleCategoryCollapse;

  const _RowsIssuesLayout({
    required this.categories,
    required this.isIssueReviewed,
    required this.onToggleIssueReviewed,
    required this.collapsedCategoryIds,
    required this.onToggleCategoryCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final rowItems = _buildRows(categories);
    return Column(
      children: [
        for (var i = 0; i < rowItems.length; i++) ...[
          _rowItemWidget(rowItems[i]),
          if (i < rowItems.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<_IssueRowItem> _buildRows(List<_IssueCategoryColumnData> categories) {
    final result = <_IssueRowItem>[];

    for (final category in categories) {
      final isCollapsed = collapsedCategoryIds.contains(category.id);
      result.add(_IssueRowItem.category(category, isCollapsed));
      if (isCollapsed) continue;
      for (final issue in category.issues) {
        result.add(_IssueRowItem.issue(issue));
      }
    }

    return result;
  }

  Widget _rowItemWidget(_IssueRowItem item) {
    if (item.category != null) {
      return _IssueRowCategoryHeader(
        category: item.category!,
        isCollapsed: item.isCollapsed,
        onToggleCollapse: () => onToggleCategoryCollapse(item.category!.id),
      );
    }

    return _IssueCard(
      issue: item.issue!,
      isReviewed: isIssueReviewed(item.issue!),
      onToggleReviewed: () => onToggleIssueReviewed(item.issue!),
      margin: EdgeInsets.zero,
    );
  }
}

class _IssueRowItem {
  final _IssueCategoryColumnData? category;
  final ReviewIssue? issue;
  final bool isCollapsed;

  const _IssueRowItem._({this.category, this.issue, this.isCollapsed = false});

  factory _IssueRowItem.category(
    _IssueCategoryColumnData value,
    bool isCollapsed,
  ) {
    return _IssueRowItem._(category: value, isCollapsed: isCollapsed);
  }

  factory _IssueRowItem.issue(ReviewIssue value) {
    return _IssueRowItem._(issue: value);
  }
}

class _IssueRowCategoryHeader extends StatelessWidget {
  final _IssueCategoryColumnData category;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const _IssueRowCategoryHeader({
    required this.category,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

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
            Chip(label: Text('${category.unresolvedIssuesCount}')),
            IconButton(
              tooltip:
                  isCollapsed ? 'Expandir categoria' : 'Minimizar categoria',
              onPressed: onToggleCollapse,
              icon: Icon(
                isCollapsed
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final ReviewIssue issue;
  final bool isReviewed;
  final VoidCallback onToggleReviewed;
  final EdgeInsetsGeometry margin;

  const _IssueCard({
    required this.issue,
    required this.isReviewed,
    required this.onToggleReviewed,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: margin,
      color: isReviewed ? colorScheme.primary.withOpacity(0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isReviewed ? colorScheme.primary : colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _titleForType(issue.type),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          isReviewed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: onToggleReviewed,
                  icon: Icon(
                    isReviewed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                  ),
                  label: const Text('Revisado'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isReviewed
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
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
