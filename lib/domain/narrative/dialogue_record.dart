/// The exact exchange heard by the player, captured before its effects run.
/// Transcript replay never evaluates another branch or applies effects.
class DialogueRecord {
  const DialogueRecord({required this.prompt, required this.response});
  final String prompt;
  final String response;
  Map<String, Object?> toJson() => {'prompt': prompt, 'response': response};
  factory DialogueRecord.fromJson(Map<String, Object?> json) => DialogueRecord(
    prompt: json['prompt'] as String,
    response: json['response'] as String,
  );
}
