enum ReviewIssueType { formattingTrigger, wordSubstitution, paragraphSymbol }

extension ReviewIssueTypeExtension on ReviewIssueType {
  static ReviewIssueType fromSnakeCase(String value) {
    switch (value) {
      case 'formatting_trigger':
      case 'italic_trigger':
        return ReviewIssueType.formattingTrigger;
      case 'word_substitution':
        return ReviewIssueType.wordSubstitution;
      case 'paragraph_symbol':
        return ReviewIssueType.paragraphSymbol;
      default:
        throw ArgumentError('Unknown issue type: $value');
    }
  }

  String toSnakeCase() {
    switch (this) {
      case ReviewIssueType.formattingTrigger:
        return 'formatting_trigger';
      case ReviewIssueType.wordSubstitution:
        return 'word_substitution';
      case ReviewIssueType.paragraphSymbol:
        return 'paragraph_symbol';
    }
  }
}

class ReviewIssue {
  final ReviewIssueType type;
  final int paragraphIndex;
  final String paragraphText;
  final String found;
  final String expected;
  final String ruleId;
  final bool autoFixable;

  const ReviewIssue({
    required this.type,
    required this.paragraphIndex,
    required this.paragraphText,
    required this.found,
    required this.expected,
    required this.ruleId,
    required this.autoFixable,
  });

  factory ReviewIssue.fromJson(Map<String, dynamic> json) {
    return ReviewIssue(
      type: ReviewIssueTypeExtension.fromSnakeCase(json['type'] as String),
      paragraphIndex: json['paragraph_index'] as int? ?? -1,
      paragraphText: (json['paragraph_text'] as String?) ?? '',
      found: (json['found'] as String?) ?? '',
      expected: (json['expected'] as String?) ?? '',
      ruleId: (json['rule_id'] as String?) ?? '',
      autoFixable: json['auto_fixable'] as bool? ?? false,
    );
  }
}

class ReviewSummary {
  final int totalIssues;
  final int formattingTrigger;
  final int wordSubstitution;
  final int paragraphSymbol;

  const ReviewSummary({
    required this.totalIssues,
    required this.formattingTrigger,
    required this.wordSubstitution,
    required this.paragraphSymbol,
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final byType = (json['by_type'] as Map<String, dynamic>?) ?? {};
    return ReviewSummary(
      totalIssues: json['total_issues'] as int? ?? 0,
      formattingTrigger:
          (byType['formatting_trigger'] as int?) ??
          (byType['italic_trigger'] as int?) ??
          0,
      wordSubstitution: byType['word_substitution'] as int? ?? 0,
      paragraphSymbol: byType['paragraph_symbol'] as int? ?? 0,
    );
  }
}

class ReviewResult {
  final ReviewSummary summary;
  final List<ReviewIssue> issues;
  final String fixedDocxBase64;
  final String fixedFilename;

  const ReviewResult({
    required this.summary,
    required this.issues,
    required this.fixedDocxBase64,
    required this.fixedFilename,
  });

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    return ReviewResult(
      summary: ReviewSummary.fromJson(
        (json['summary'] as Map<String, dynamic>?) ?? {},
      ),
      issues:
          ((json['issues'] as List<dynamic>?) ?? [])
              .map(
                (issue) => ReviewIssue.fromJson(issue as Map<String, dynamic>),
              )
              .toList(),
      fixedDocxBase64: (json['fixed_docx_base64'] as String?) ?? '',
      fixedFilename: (json['fixed_filename'] as String?) ?? 'reviewed.docx',
    );
  }
}
