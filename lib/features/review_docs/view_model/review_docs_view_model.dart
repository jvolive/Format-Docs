import 'package:flutter/foundation.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_docs/view_model/review_docs_file_view_model.dart';
import 'package:format_docs/features/review_html/view_model/review_html_view_model.dart';

enum ReviewDocsStatus { initial, loading, success, error }

class ReviewIssueBuckets {
  final List<ReviewIssue> formatting;
  final List<ReviewIssue> substitutions;
  final List<ReviewIssue> symbols;

  const ReviewIssueBuckets({
    required this.formatting,
    required this.substitutions,
    required this.symbols,
  });

  static const empty = ReviewIssueBuckets(
    formatting: <ReviewIssue>[],
    substitutions: <ReviewIssue>[],
    symbols: <ReviewIssue>[],
  );
}

class ReviewDocsViewModel extends ChangeNotifier {
  final ReviewDocsFileViewModel _docsFileViewModel;
  final ReviewHtmlViewModel _reviewHtmlViewModel;

  ReviewDocsViewModel({
    required ReviewDocsFileViewModel docsFileViewModel,
    required ReviewHtmlViewModel reviewHtmlViewModel,
  }) : _docsFileViewModel = docsFileViewModel,
       _reviewHtmlViewModel = reviewHtmlViewModel;

  ReviewDocsStatus _status = ReviewDocsStatus.initial;
  ReviewResult? _result;
  ReviewIssueBuckets _issueBuckets = ReviewIssueBuckets.empty;
  String? _errorMessage;
  String? _fileName;

  ReviewDocsStatus get status => _status;
  ReviewResult? get result => _result;
  ReviewIssueBuckets get issueBuckets => _issueBuckets;
  String? get errorMessage => _errorMessage;
  String? get fileName => _fileName;
  bool get isLoading => _status == ReviewDocsStatus.loading;

  Future<void> reviewDocument({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    _status = ReviewDocsStatus.loading;
    _result = null;
    _issueBuckets = ReviewIssueBuckets.empty;
    _errorMessage = null;
    _fileName = fileName;
    notifyListeners();

    try {
      if (_isHtmlFile(fileName)) {
        await _reviewHtmlViewModel.reviewHtml(
          fileName: fileName,
          fileBytes: fileBytes,
        );
        _syncFromHtmlViewModel();
      } else {
        await _docsFileViewModel.reviewDocument(
          fileName: fileName,
          fileBytes: fileBytes,
        );
        _syncFromDocsViewModel();
      }

      if (_status == ReviewDocsStatus.success) {
        _issueBuckets = await _buildIssueBuckets(_result?.issues ?? const []);
      }
    } catch (error) {
      _status = ReviewDocsStatus.error;
      _result = null;
      _issueBuckets = ReviewIssueBuckets.empty;
      _errorMessage = _normalizeError(error);
    }

    notifyListeners();
  }

  void clear() {
    _docsFileViewModel.clear();
    _reviewHtmlViewModel.clear();

    _status = ReviewDocsStatus.initial;
    _result = null;
    _issueBuckets = ReviewIssueBuckets.empty;
    _errorMessage = null;
    _fileName = null;
    notifyListeners();
  }

  void _syncFromDocsViewModel() {
    _result = _docsFileViewModel.result;
    _errorMessage = _docsFileViewModel.errorMessage;
    _status = _mapDocsStatus(_docsFileViewModel.status);
  }

  void _syncFromHtmlViewModel() {
    _result = _reviewHtmlViewModel.result;
    _errorMessage = _reviewHtmlViewModel.errorMessage;
    _status = _mapHtmlStatus(_reviewHtmlViewModel.status);
  }

  ReviewDocsStatus _mapDocsStatus(ReviewDocsFileStatus status) {
    switch (status) {
      case ReviewDocsFileStatus.initial:
        return ReviewDocsStatus.initial;
      case ReviewDocsFileStatus.loading:
        return ReviewDocsStatus.loading;
      case ReviewDocsFileStatus.success:
        return ReviewDocsStatus.success;
      case ReviewDocsFileStatus.error:
        return ReviewDocsStatus.error;
    }
  }

  ReviewDocsStatus _mapHtmlStatus(ReviewHtmlStatus status) {
    switch (status) {
      case ReviewHtmlStatus.initial:
        return ReviewDocsStatus.initial;
      case ReviewHtmlStatus.loading:
        return ReviewDocsStatus.loading;
      case ReviewHtmlStatus.success:
        return ReviewDocsStatus.success;
      case ReviewHtmlStatus.error:
        return ReviewDocsStatus.error;
    }
  }

  bool _isHtmlFile(String fileName) {
    final normalized = fileName.toLowerCase();
    return normalized.endsWith('.html') || normalized.endsWith('.htm');
  }

  String _normalizeError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  Future<ReviewIssueBuckets> _buildIssueBuckets(
    List<ReviewIssue> issues,
  ) async {
    if (issues.isEmpty) return ReviewIssueBuckets.empty;

    try {
      final groupedIndexes = await compute(
        _groupIssueIndexesWorker,
        issues.map((issue) => issue.type.toSnakeCase()).toList(growable: false),
      );

      return ReviewIssueBuckets(
        formatting: _issuesFromIndexes(
          issues,
          groupedIndexes['formatting_trigger'],
        ),
        substitutions: _issuesFromIndexes(
          issues,
          groupedIndexes['word_substitution'],
        ),
        symbols: _issuesFromIndexes(issues, groupedIndexes['paragraph_symbol']),
      );
    } catch (_) {
      return _buildIssueBucketsOnMainIsolate(issues);
    }
  }

  ReviewIssueBuckets _buildIssueBucketsOnMainIsolate(List<ReviewIssue> issues) {
    final formatting = <ReviewIssue>[];
    final substitutions = <ReviewIssue>[];
    final symbols = <ReviewIssue>[];

    for (final issue in issues) {
      switch (issue.type) {
        case ReviewIssueType.formattingTrigger:
          formatting.add(issue);
          break;
        case ReviewIssueType.wordSubstitution:
          substitutions.add(issue);
          break;
        case ReviewIssueType.paragraphSymbol:
          symbols.add(issue);
          break;
      }
    }

    return ReviewIssueBuckets(
      formatting: List<ReviewIssue>.unmodifiable(formatting),
      substitutions: List<ReviewIssue>.unmodifiable(substitutions),
      symbols: List<ReviewIssue>.unmodifiable(symbols),
    );
  }

  List<ReviewIssue> _issuesFromIndexes(
    List<ReviewIssue> source,
    List<int>? indexes,
  ) {
    if (indexes == null || indexes.isEmpty) return const <ReviewIssue>[];

    return List<ReviewIssue>.unmodifiable(
      indexes
          .where((index) => index >= 0 && index < source.length)
          .map((index) => source[index]),
    );
  }
}

Map<String, List<int>> _groupIssueIndexesWorker(List<String> issueTypes) {
  final grouped = <String, List<int>>{
    'formatting_trigger': <int>[],
    'word_substitution': <int>[],
    'paragraph_symbol': <int>[],
  };

  for (var i = 0; i < issueTypes.length; i++) {
    final type = issueTypes[i];
    final target = grouped[type];
    if (target != null) {
      target.add(i);
    }
  }

  return grouped;
}
