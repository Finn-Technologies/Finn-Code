class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.displayName,
    this.contextWindow,
    this.isFree = false,
    this.supportsTools = false,
  });

  final String id;
  final String displayName;
  final int? contextWindow;
  final bool isFree;
  final bool supportsTools;

  factory ModelInfo.fromOpenAiJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String? ?? 'unknown',
      displayName:
          json['name'] as String? ?? json['id'] as String? ?? 'Unknown',
      contextWindow: _asInt(json['context_length'] ?? json['context_window']),
      isFree:
          _asDouble(json['pricing']?['prompt']) == 0 &&
          _asDouble(json['pricing']?['completion']) == 0,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
