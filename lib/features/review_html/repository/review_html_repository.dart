import 'dart:typed_data';

import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:format_docs/features/review_html/data/review_html_api_client.dart';

abstract interface class ReviewHtmlRepositoryInterface {
  Future<ReviewResult> reviewHtml({
    required String fileName,
    required Uint8List fileBytes,
  });
}

class ReviewHtmlRepository implements ReviewHtmlRepositoryInterface {
  final ReviewHtmlApiClient _apiClient;

  const ReviewHtmlRepository({required ReviewHtmlApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<ReviewResult> reviewHtml({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return _apiClient.reviewHtml(fileName: fileName, fileBytes: fileBytes);
  }
}
