import 'dart:convert';

import 'package:format_docs/features/rules/data/rules_dto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class RulesApiClient {
  final String functionsUrl;
  final SupabaseClient supabaseClient;

  const RulesApiClient({
    required this.functionsUrl,
    required this.supabaseClient,
  });

  String get _baseUrl => '$functionsUrl/manage-rules';

  Future<String> get _authToken async {
    final session = supabaseClient.auth.currentSession;
    if (session == null) throw Exception('User not authenticated');
    return session.accessToken;
  }

  Future<Map<String, String>> get _headers async {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await _authToken}',
    };
  }

  // GET /manage-rules
  Future<List<RuleDTO>> fetchRules() async {
    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: await _headers,
    );

    _checkStatus(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List;
    return data
        .map((e) => RuleDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // POST /manage-rules
  Future<RuleDTO> createRule(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: await _headers,
      body: jsonEncode(payload),
    );

    _checkStatus(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RuleDTO.fromJson(json['data'] as Map<String, dynamic>);
  }

  // PUT /manage-rules?id=:id
  Future<RuleDTO> updateRule(String id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse('$_baseUrl?id=$id'),
      headers: await _headers,
      body: jsonEncode(payload),
    );

    _checkStatus(response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return RuleDTO.fromJson(json['data'] as Map<String, dynamic>);
  }

  // DELETE /manage-rules?id=:id
  Future<void> deleteRule(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl?id=$id'),
      headers: await _headers,
    );

    _checkStatus(response);
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 400) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(json['error'] ?? 'Unknown error');
    }
  }
}
