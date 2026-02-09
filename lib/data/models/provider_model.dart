import '../../domain/entities/provider.dart';

/// Technical comment translated to English.
class ProvidersResponseModel {
  const ProvidersResponseModel({
    required this.providers,
    required this.defaultModels,
    this.connected = const [],
  });

  final List<ProviderModel> providers;
  final Map<String, String> defaultModels;
  final List<String> connected;

  /// Parse both old (`{providers, default}`) and new (`{all, default, connected}`) schemas.
  factory ProvidersResponseModel.fromJson(Map<String, dynamic> json) {
    // New API uses 'all', old API uses 'providers'
    final providersList = (json['all'] as List<dynamic>?) ??
        (json['providers'] as List<dynamic>?) ??
        <dynamic>[];

    final providers = providersList
        .map((e) => ProviderModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final defaultModels = json['default'] != null
        ? Map<String, String>.from(json['default'] as Map)
        : <String, String>{};

    final connected = (json['connected'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];

    return ProvidersResponseModel(
      providers: providers,
      defaultModels: defaultModels,
      connected: connected,
    );
  }

  Map<String, dynamic> toJson() => {
        'providers': providers.map((p) => p.toJson()).toList(),
        'default': defaultModels,
        'connected': connected,
      };

  ProvidersResponse toDomain() {
    return ProvidersResponse(
      providers: providers.map((p) => p.toDomain()).toList(),
      defaultModels: defaultModels,
      connected: connected,
    );
  }
}

/// Provider model - supports both old and new API formats.
class ProviderModel {
  const ProviderModel({
    required this.id,
    required this.name,
    required this.env,
    this.api,
    this.npm,
    required this.models,
  });

  final String id;
  final String name;
  final List<String> env;
  final String? api;
  final String? npm;
  final Map<String, ModelModel> models;

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    // Parse env: may be List<String> or absent
    final envList = (json['env'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];

    // Parse models map
    final modelsMap = <String, ModelModel>{};
    final modelsJson = json['models'] as Map<String, dynamic>?;
    if (modelsJson != null) {
      for (final entry in modelsJson.entries) {
        try {
          modelsMap[entry.key] =
              ModelModel.fromJson(entry.value as Map<String, dynamic>);
        } catch (e) {
          // Skip models that fail to parse
        }
      }
    }

    return ProviderModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      env: envList,
      api: json['api'] is String ? json['api'] as String : null,
      npm: json['npm'] as String?,
      models: modelsMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'env': env,
        'api': api,
        'npm': npm,
        'models': models.map((k, v) => MapEntry(k, v.toJson())),
      };

  Provider toDomain() {
    return Provider(
      id: id,
      name: name,
      env: env,
      api: api,
      npm: npm,
      models: models.map((key, value) => MapEntry(key, value.toDomain())),
    );
  }
}

/// Model - supports both flat fields and nested capabilities format.
class ModelModel {
  const ModelModel({
    required this.id,
    required this.name,
    required this.releaseDate,
    required this.attachment,
    required this.reasoning,
    required this.temperature,
    required this.toolCall,
    required this.cost,
    required this.limit,
    this.options = const {},
    this.knowledge,
    this.lastUpdated,
    this.modalities,
    this.openWeights,
  });

  final String id;
  final String name;
  final String releaseDate;
  final bool attachment;
  final bool reasoning;
  final bool temperature;
  final bool toolCall;
  final ModelCostModel cost;
  final ModelLimitModel limit;
  final Map<String, dynamic>? options;
  final String? knowledge;
  final String? lastUpdated;
  final Map<String, dynamic>? modalities;
  final bool? openWeights;

  /// Parse model from JSON, supporting both flat and capabilities-nested formats.
  factory ModelModel.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'] as Map<String, dynamic>?;

    // Extract booleans from capabilities or flat fields
    final attachment = capabilities?['attachment'] as bool? ??
        json['attachment'] as bool? ??
        false;
    final reasoning = capabilities?['reasoning'] as bool? ??
        json['reasoning'] as bool? ??
        false;
    final temperature = capabilities?['temperature'] as bool? ??
        json['temperature'] as bool? ??
        false;
    final toolCall = capabilities?['toolcall'] as bool? ??
        json['tool_call'] as bool? ??
        false;

    return ModelModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      releaseDate: json['release_date'] as String? ?? '',
      attachment: attachment,
      reasoning: reasoning,
      temperature: temperature,
      toolCall: toolCall,
      cost: ModelCostModel.fromJson(json['cost'] as Map<String, dynamic>),
      limit: ModelLimitModel.fromJson(json['limit'] as Map<String, dynamic>),
      options: json['options'] as Map<String, dynamic>?,
      knowledge: json['knowledge'] as String?,
      lastUpdated: json['last_updated'] as String?,
      modalities: json['modalities'] as Map<String, dynamic>?,
      openWeights: json['open_weights'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'release_date': releaseDate,
        'attachment': attachment,
        'reasoning': reasoning,
        'temperature': temperature,
        'tool_call': toolCall,
        'cost': cost.toJson(),
        'limit': limit.toJson(),
        'options': options,
        'knowledge': knowledge,
        'last_updated': lastUpdated,
        'modalities': modalities,
        'open_weights': openWeights,
      };

  Model toDomain() {
    return Model(
      id: id,
      name: name,
      releaseDate: releaseDate,
      attachment: attachment,
      reasoning: reasoning,
      temperature: temperature,
      toolCall: toolCall,
      cost: cost.toDomain(),
      limit: limit.toDomain(),
      options: options ?? {},
      knowledge: knowledge,
      lastUpdated: lastUpdated,
      modalities: modalities,
      openWeights: openWeights,
    );
  }
}

/// Model cost - supports both flat fields and nested cache format.
class ModelCostModel {
  const ModelCostModel({
    required this.input,
    required this.output,
    this.cacheRead,
    this.cacheWrite,
  });

  final double input;
  final double output;
  final double? cacheRead;
  final double? cacheWrite;

  static double _doubleFromJson(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _nullableDoubleFromJson(dynamic value) {
    if (value == null) return null;
    return _doubleFromJson(value);
  }

  /// Parse cost from JSON, supporting both `{cache_read, cache_write}` and `{cache: {read, write}}`.
  factory ModelCostModel.fromJson(Map<String, dynamic> json) {
    final cache = json['cache'] as Map<String, dynamic>?;
    return ModelCostModel(
      input: _doubleFromJson(json['input']),
      output: _doubleFromJson(json['output']),
      cacheRead: _nullableDoubleFromJson(cache?['read'] ?? json['cache_read']),
      cacheWrite:
          _nullableDoubleFromJson(cache?['write'] ?? json['cache_write']),
    );
  }

  Map<String, dynamic> toJson() => {
        'input': input,
        'output': output,
        'cache_read': cacheRead,
        'cache_write': cacheWrite,
      };

  ModelCost toDomain() {
    return ModelCost(
      input: input,
      output: output,
      cacheRead: cacheRead,
      cacheWrite: cacheWrite,
    );
  }
}

/// Model limits.
class ModelLimitModel {
  const ModelLimitModel({required this.context, required this.output});

  final int context;
  final int output;

  factory ModelLimitModel.fromJson(Map<String, dynamic> json) {
    return ModelLimitModel(
      context: (json['context'] as num?)?.toInt() ?? 0,
      output: (json['output'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() =>
      {'context': context, 'output': output};

  ModelLimit toDomain() {
    return ModelLimit(context: context, output: output);
  }
}
