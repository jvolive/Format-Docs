import 'package:flutter/foundation.dart';
import 'package:format_docs/features/rules/models/rules.dart';

import '../repository/rules_repository.dart';

enum RulesStatus { initial, loading, success, error }

class RulesViewModel extends ChangeNotifier {
  final RulesRepositoryInterface _repository;

  RulesViewModel({required RulesRepositoryInterface repository})
    : _repository = repository;

  RulesStatus _status = RulesStatus.initial;
  List<Rule> _rules = [];
  String? _errorMessage;

  RulesStatus get status => _status;
  List<Rule> get rules => List.unmodifiable(_rules);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RulesStatus.loading;

  Future<void> fetchRules() async {
    _setLoading();
    try {
      _rules = await _repository.fetchRules();
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> createRule(Rule rule) async {
    _setLoading();
    try {
      final created = await _repository.createRule(rule);
      _rules = [created, ..._rules];
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> updateRule(Rule rule) async {
    _setLoading();
    try {
      final updated = await _repository.updateRule(rule);
      _rules = _rules.map((r) => r.id == updated.id ? updated : r).toList();
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> deleteRule(String id) async {
    _setLoading();
    try {
      await _repository.deleteRule(id);
      _rules = _rules.where((r) => r.id != id).toList();
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  void _setLoading() {
    _status = RulesStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setSuccess() {
    _status = RulesStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _status = RulesStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}
