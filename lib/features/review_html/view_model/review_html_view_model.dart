import 'package:flutter/foundation.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_html/repository/review_html_repository.dart';

enum ReviewHtmlStatus { initial, loading, success, error }

class ReviewHtmlViewModel extends ChangeNotifier {
  final ReviewHtmlRepositoryInterface _repository;

  ReviewHtmlViewModel({required ReviewHtmlRepositoryInterface repository})
    : _repository = repository;

  ReviewHtmlStatus _status = ReviewHtmlStatus.initial;
  ReviewResult? _result;
  String? _errorMessage;
  String? _fileName;

  ReviewHtmlStatus get status => _status;
  ReviewResult? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get fileName => _fileName;
  bool get isLoading => _status == ReviewHtmlStatus.loading;

  Future<void> reviewHtml({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    _status = ReviewHtmlStatus.loading;
    _errorMessage = null;
    _fileName = fileName;
    notifyListeners();

    try {
      _result = await _repository.reviewHtml(
        fileName: fileName,
        fileBytes: fileBytes,
      );
      _status = ReviewHtmlStatus.success;
      notifyListeners();
    } catch (error) {
      _status = ReviewHtmlStatus.error;
      _errorMessage = _normalizeError(error);
      notifyListeners();
    }
  }

  void clear() {
    _status = ReviewHtmlStatus.initial;
    _result = null;
    _errorMessage = null;
    _fileName = null;
    notifyListeners();
  }

  String _normalizeError(Object error) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    return message;
  }
}
