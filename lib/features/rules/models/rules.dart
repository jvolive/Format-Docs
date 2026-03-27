enum RuleType { formattingTrigger, wordSubstitution, paragraphSymbol }

extension RuleTypeExtension on RuleType {
  String toSnakeCase() {
    switch (this) {
      case RuleType.formattingTrigger:
        return 'formatting_trigger';
      case RuleType.wordSubstitution:
        return 'word_substitution';
      case RuleType.paragraphSymbol:
        return 'paragraph_symbol';
    }
  }

  static RuleType fromSnakeCase(String value) {
    switch (value) {
      case 'formatting_trigger':
      case 'italic_trigger':
        return RuleType.formattingTrigger;
      case 'word_substitution':
        return RuleType.wordSubstitution;
      case 'paragraph_symbol':
        return RuleType.paragraphSymbol;
      default:
        throw ArgumentError('Unknown rule_type: $value');
    }
  }
}

class Rule {
  final String? id;
  final String triggerWord;
  final RuleType ruleType;
  final String? replacement;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Rule({
    this.id,
    required this.triggerWord,
    required this.ruleType,
    this.replacement,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.color,
    this.createdAt,
    this.updatedAt,
  });

  Rule copyWith({
    String? id,
    String? triggerWord,
    RuleType? ruleType,
    String? replacement,
    bool? bold,
    bool? italic,
    bool? underline,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Rule(
      id: id ?? this.id,
      triggerWord: triggerWord ?? this.triggerWord,
      ruleType: ruleType ?? this.ruleType,
      replacement: replacement ?? this.replacement,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Rule && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
