import 'guide_models.dart';

/// Provider-neutral boundary for OPTIONAL AI-assisted passage selection.
///
/// No provider is installed in the shipping build. A configured implementation
/// must call a backend proxy that owns secrets, never an LLM using client keys.
/// It receives only approved passages, intent and level, with no save, flags,
/// inventory identifiers, history, hidden content, or free-form player input.
///
/// Return exactly {"passageIds": ["p0"]}, selecting at most two supplied IDs.
/// Unrestricted generated prose is deliberately unsupported: no filter can
/// reliably prove that arbitrary model text contains no story spoilers.
abstract interface class GuideProvider {
  String get displayName;
  Future<Object?> selectPassages(GuideRequest request);
}

class GuideRequest {
  GuideRequest({
    required this.intent,
    required this.level,
    required List<GuidePassage> passages,
  }) : passages = List.unmodifiable(passages);
  final GuideIntent intent;
  final HintLevel level;
  final List<GuidePassage> passages;
  Map<String, Object?> toJson() => {
    'intent': intent.name,
    'hintLevel': level.name,
    'passages': passages.map((p) => p.toJson()).toList(growable: false),
  };
}
