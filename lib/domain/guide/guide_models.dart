/// Guide data contains approved prose only: never game commands or save data.
enum HintLevel { subtle, guided, direct }

enum GuideIntent { progress, evidence }

enum GuideSource { offline, aiSelection }

enum GuideFallback { none, unavailable, timeout, invalidResponse }

class GuideTopic {
  const GuideTopic({
    required this.id,
    required this.title,
    required this.intent,
  });
  final String id;
  final String title;
  final GuideIntent intent;
}

class GuidePassage {
  const GuidePassage(this.id, this.text);
  final String id;
  final String text;
  Map<String, Object?> toJson() => {'id': id, 'text': text};
}

/// Immutable allowlist for one intent, discovery snapshot, and hint level.
class GuidePlan {
  GuidePlan({
    required this.topic,
    required this.level,
    required this.offlineText,
    required List<GuidePassage> passages,
  }) : passages = List.unmodifiable(passages);
  final GuideTopic topic;
  final HintLevel level;
  final String offlineText;
  final List<GuidePassage> passages;
}

class GuideReply {
  const GuideReply({
    required this.text,
    required this.level,
    this.source = GuideSource.offline,
    this.fallback = GuideFallback.none,
  });
  final String text;
  final HintLevel level;
  final GuideSource source;
  final GuideFallback fallback;
}
