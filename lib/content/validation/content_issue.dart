/// Severity of a validation finding.
enum IssueSeverity { error, warning }

/// A single validation finding with a stable [code] for tests and tooling.
class ContentIssue {
  const ContentIssue(this.severity, this.code, this.message);

  const ContentIssue.error(String code, String message)
    : this(IssueSeverity.error, code, message);

  const ContentIssue.warning(String code, String message)
    : this(IssueSeverity.warning, code, message);

  final IssueSeverity severity;
  final String code;
  final String message;

  @override
  String toString() => '[${severity.name}] $code: $message';
}

/// One reachable ending and an example route (choice option ids) to it.
class EndingRoute {
  const EndingRoute(this.endingId, this.options, this.leafCount);

  final String endingId;

  /// Option ids chosen along one example playthrough.
  final List<String> options;

  /// How many distinct choice combinations lead here.
  final int leafCount;
}

/// Result of validating the content.
class ValidationReport {
  const ValidationReport({
    required this.issues,
    required this.endingRoutes,
    required this.playthroughCount,
    required this.dependencyOrder,
  });

  final List<ContentIssue> issues;

  /// Reachable endings with an example route each.
  final List<EndingRoute> endingRoutes;

  /// Number of distinct choice combinations simulated.
  final int playthroughCount;

  /// Mandatory puzzles in an order that satisfies all dependencies.
  final List<String> dependencyOrder;

  List<ContentIssue> get errors =>
      issues.where((i) => i.severity == IssueSeverity.error).toList();

  List<ContentIssue> get warnings =>
      issues.where((i) => i.severity == IssueSeverity.warning).toList();

  bool get isValid => errors.isEmpty;

  bool hasCode(String code) => issues.any((i) => i.code == code);

  String describe() => issues.isEmpty ? 'No issues.' : issues.join('\n');
}
