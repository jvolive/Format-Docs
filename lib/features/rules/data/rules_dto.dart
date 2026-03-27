import 'package:format_docs/features/rules/models/rules.dart';

class RuleDTO {
  final String id;
  final String triggerWord;
  final String ruleType;
  final String? replacement;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? color;
  final String createdAt;
  final String updatedAt;

  const RuleDTO({
    required this.id,
    required this.triggerWord,
    required this.ruleType,
    this.replacement,
    required this.bold,
    required this.italic,
    required this.underline,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RuleDTO.fromJson(Map<String, dynamic> json) {
    return RuleDTO(
      id: json['id'] as String,
      triggerWord: json['trigger_word'] as String,
      ruleType: json['rule_type'] as String,
      replacement: json['replacement'] as String?,
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      color: json['color'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trigger_word': triggerWord,
      'rule_type': ruleType,
      'replacement': replacement,
      'bold': bold,
      'italic': italic,
      'underline': underline,
      'color': color,
    };
  }

  Rule toModel() {
    return Rule(
      id: id,
      triggerWord: triggerWord,
      ruleType: RuleTypeExtension.fromSnakeCase(ruleType),
      replacement: replacement,
      bold: bold,
      italic: italic,
      underline: underline,
      color: color,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  static Map<String, dynamic> fromModel(Rule rule) {
    return {
      'trigger_word': rule.triggerWord,
      'rule_type': rule.ruleType.toSnakeCase(),
      'replacement': rule.replacement,
      'bold': rule.bold,
      'italic': rule.italic,
      'underline': rule.underline,
      'color': rule.color,
    };
  }
}
