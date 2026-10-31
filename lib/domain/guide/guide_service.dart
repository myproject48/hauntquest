import 'dart:async';

import 'guide_models.dart';
import 'guide_provider.dart';
import 'offline_guide.dart';

/// An optional provider may SELECT approved prose, but cannot add prose,
/// escalate a tier, request hidden evidence, or return executable actions.
class GuideService {
  GuideService({
    required this.offline,
    this.provider,
    this.timeout = const Duration(seconds: 3),
  }) : assert(timeout > Duration.zero);
  final OfflineGuide offline;
  final GuideProvider? provider;
  final Duration timeout;
  bool get aiConfigured => provider != null;

  Future<GuideReply> reply(GuidePlan plan, {bool useAi = false}) async {
    GuideReply fallback([GuideFallback reason = GuideFallback.none]) =>
        GuideReply(text: plan.offlineText, level: plan.level, fallback: reason);
    if (!useAi || provider == null) return fallback();
    try {
      final raw = await provider!
          .selectPassages(
            GuideRequest(
              intent: plan.topic.intent,
              level: plan.level,
              passages: plan.passages,
            ),
          )
          .timeout(timeout);
      if (raw is! Map || raw.length != 1 || !raw.containsKey('passageIds')) {
        return fallback(GuideFallback.invalidResponse);
      }
      final ids = raw['passageIds'];
      if (ids is! List ||
          ids.isEmpty ||
          ids.length > 2 ||
          ids.any((id) => id is! String) ||
          ids.toSet().length != ids.length) {
        return fallback(GuideFallback.invalidResponse);
      }
      final allowed = {for (final p in plan.passages) p.id: p.text};
      if (ids.any((id) => !allowed.containsKey(id))) {
        return fallback(GuideFallback.invalidResponse);
      }
      return GuideReply(
        text: ids.map((id) => allowed[id]!).join('\n\n'),
        level: plan.level,
        source: GuideSource.aiSelection,
      );
    } on TimeoutException {
      return fallback(GuideFallback.timeout);
    } catch (_) {
      // Never display provider errors, stack traces, tokens or raw model text.
      return fallback(GuideFallback.unavailable);
    }
  }
}
