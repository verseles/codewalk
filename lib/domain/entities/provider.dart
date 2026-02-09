import 'package:equatable/equatable.dart';

/// Technical comment translated to English.
class Provider extends Equatable {
  final String id;
  final String name;
  final List<String> env;
  final String? api;
  final String? npm;
  final Map<String, Model> models;

  const Provider({
    required this.id,
    required this.name,
    required this.env,
    this.api,
    this.npm,
    required this.models,
  });

  @override
  List<Object?> get props => [id, name, env, api, npm, models];
}

/// Technical comment translated to English.
class Model extends Equatable {
  final String id;
  final String name;
  final String releaseDate;
  final bool attachment;
  final bool reasoning;
  final bool temperature;
  final bool toolCall;
  final ModelCost cost;
  final ModelLimit limit;
  final Map<String, dynamic> options;
  final String? knowledge;
  final String? lastUpdated;
  final Map<String, dynamic>? modalities;
  final bool? openWeights;

  const Model({
    required this.id,
    required this.name,
    required this.releaseDate,
    required this.attachment,
    required this.reasoning,
    required this.temperature,
    required this.toolCall,
    required this.cost,
    required this.limit,
    required this.options,
    this.knowledge,
    this.lastUpdated,
    this.modalities,
    this.openWeights,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    releaseDate,
    attachment,
    reasoning,
    temperature,
    toolCall,
    cost,
    limit,
    options,
    knowledge,
    lastUpdated,
    modalities,
    openWeights,
  ];
}

/// Technical comment translated to English.
class ModelCost extends Equatable {
  final double input;
  final double output;
  final double? cacheRead;
  final double? cacheWrite;

  const ModelCost({
    required this.input,
    required this.output,
    this.cacheRead,
    this.cacheWrite,
  });

  @override
  List<Object?> get props => [input, output, cacheRead, cacheWrite];
}

/// Technical comment translated to English.
class ModelLimit extends Equatable {
  final int context;
  final int output;

  const ModelLimit({required this.context, required this.output});

  @override
  List<Object> get props => [context, output];
}

/// Technical comment translated to English.
class ProvidersResponse extends Equatable {
  final List<Provider> providers;
  final Map<String, String> defaultModels;
  final List<String> connected;

  const ProvidersResponse({
    required this.providers,
    required this.defaultModels,
    this.connected = const [],
  });

  @override
  List<Object> get props => [providers, defaultModels, connected];
}
