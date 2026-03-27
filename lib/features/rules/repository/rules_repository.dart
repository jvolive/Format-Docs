
import 'package:format_docs/features/rules/data/rules_api_client.dart';
import 'package:format_docs/features/rules/data/rules_dto.dart';
import 'package:format_docs/features/rules/models/rules.dart';

abstract interface class RulesRepositoryInterface {
  Future<List<Rule>> fetchRules();
  Future<Rule> createRule(Rule rule);
  Future<Rule> updateRule(Rule rule);
  Future<void> deleteRule(String id);
}

class RulesRepository implements RulesRepositoryInterface {
  final RulesApiClient _apiClient;

  const RulesRepository({required RulesApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<Rule>> fetchRules() async {
    final dtos = await _apiClient.fetchRules();
    return dtos.map((dto) => dto.toModel()).toList();
  }

  @override
  Future<Rule> createRule(Rule rule) async {
    final payload = RuleDTO.fromModel(rule);
    final dto = await _apiClient.createRule(payload);
    return dto.toModel();
  }

  @override
  Future<Rule> updateRule(Rule rule) async {
    if (rule.id == null) throw ArgumentError('Rule id is required for update');
    final payload = RuleDTO.fromModel(rule);
    final dto = await _apiClient.updateRule(rule.id!, payload);
    return dto.toModel();
  }

  @override
  Future<void> deleteRule(String id) async {
    await _apiClient.deleteRule(id);
  }
}