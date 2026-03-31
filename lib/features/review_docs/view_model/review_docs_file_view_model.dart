import 'package:flutter/foundation.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_docs/repository/review_docs_repository.dart';

enum ReviewDocsFileStatus { initial, loading, success, error }

class ReviewDocsFileViewModel extends ChangeNotifier {
  final ReviewDocsRepositoryInterface _repository;

  ReviewDocsFileViewModel({required ReviewDocsRepositoryInterface repository})
    : _repository = repository;

  ReviewDocsFileStatus _status = ReviewDocsFileStatus.initial;
  ReviewResult? _result;
  String? _errorMessage;
  String? _fileName;

  ReviewDocsFileStatus get status => _status;
  ReviewResult? get result => _result;
  String? get errorMessage => _errorMessage;
  String? get fileName => _fileName;
  bool get isLoading => _status == ReviewDocsFileStatus.loading;

  Future<void> reviewDocument({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    _status = ReviewDocsFileStatus.loading;
    _errorMessage = null;
    _fileName = fileName;
    notifyListeners();

    try {
      _result = await _repository.reviewDocument(
        fileName: fileName,
        fileBytes: fileBytes,
      );
      _status = ReviewDocsFileStatus.success;
      notifyListeners();
    } catch (error) {
      _status = ReviewDocsFileStatus.error;
      _errorMessage = _normalizeError(error);
      notifyListeners();
    }
  }

  void clear() {
    _status = ReviewDocsFileStatus.initial;
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
