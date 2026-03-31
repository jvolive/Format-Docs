import 'package:flutter/foundation.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_docs/view_model/review_docs_file_view_model.dart';
import 'package:format_docs/features/review_html/view_model/review_html_view_model.dart';

enum ReviewDocsStatus { initial, loading, success, error }

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
  String? _errorMessage;
  String? _fileName;

  ReviewDocsStatus get status => _status;
  ReviewResult? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get fileName => _fileName;
  bool get isLoading => _status == ReviewDocsStatus.loading;

  Future<void> reviewDocument({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    _status = ReviewDocsStatus.loading;
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
    } catch (error) {
      _status = ReviewDocsStatus.error;
      _errorMessage = _normalizeError(error);
    }

    notifyListeners();
  }

  void clear() {
    _docsFileViewModel.clear();
    _reviewHtmlViewModel.clear();

    _status = ReviewDocsStatus.initial;
    _result = null;
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
}
