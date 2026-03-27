import 'dart:typed_data';

import 'package:format_docs/features/review_docs/data/review_docs_api_client.dart';
import 'package:format_docs/features/review_docs/models/review_result.dart';

abstract interface class ReviewDocsRepositoryInterface {
  Future<ReviewResult> reviewDocument({
    required String fileName,
    required Uint8List fileBytes,
  });
}

class ReviewDocsRepository implements ReviewDocsRepositoryInterface {
  final ReviewDocsApiClient _apiClient;

  const ReviewDocsRepository({required ReviewDocsApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<ReviewResult> reviewDocument({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return _apiClient.reviewDocument(fileName: fileName, fileBytes: fileBytes);
  }
}
