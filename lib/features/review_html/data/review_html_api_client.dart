import 'dart:convert';
import 'dart:typed_data';

import 'package:format_docs/features/review_docs/models/review_result.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewHtmlApiClient {
  final String functionsUrl;
  final SupabaseClient supabaseClient;

  const ReviewHtmlApiClient({
    required this.functionsUrl,
    required this.supabaseClient,
  });

  Uri get _uri => Uri.parse('$functionsUrl/review-html');

  Future<String> get _authToken async {
    final session = supabaseClient.auth.currentSession;
    if (session == null) throw Exception('Usuário não autenticado');
    return session.accessToken;
  }

  Future<ReviewResult> reviewHtml({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final request =
        http.MultipartRequest('POST', _uri)
          ..headers['Authorization'] = 'Bearer ${await _authToken}'
          ..files.add(
            http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
          );

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode >= 400) {
      throw Exception(_extractError(responseBody));
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return ReviewResult.fromJson(json);
  }

  String _extractError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final message = json['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      return 'Falha ao revisar HTML';
    } catch (_) {
      return 'Falha ao revisar HTML';
    }
  }
}
