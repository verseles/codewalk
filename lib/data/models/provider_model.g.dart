// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProviderModel _$ProviderModelFromJson(Map<String, dynamic> json) =>
    ProviderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      env: (json['env'] as List<dynamic>).map((e) => e as String).toList(),
      api: json['api'] as String?,
      npm: json['npm'] as String?,
      models: (json['models'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, ModelModel.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$ProviderModelToJson(ProviderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'env': instance.env,
      'api': instance.api,
      'npm': instance.npm,
      'models': instance.models,
    };

ModelModel _$ModelModelFromJson(Map<String, dynamic> json) => ModelModel(
  id: json['id'] as String,
  name: json['name'] as String,
  releaseDate: json['release_date'] as String,
  attachment: json['attachment'] as bool,
  reasoning: json['reasoning'] as bool,
  temperature: json['temperature'] as bool,
  toolCall: json['tool_call'] as bool,
  cost: ModelCostModel.fromJson(json['cost'] as Map<String, dynamic>),
  limit: ModelLimitModel.fromJson(json['limit'] as Map<String, dynamic>),
  options: json['options'] as Map<String, dynamic>? ?? const {},
  knowledge: json['knowledge'] as String?,
  lastUpdated: json['last_updated'] as String?,
  modalities: json['modalities'] as Map<String, dynamic>?,
  openWeights: json['open_weights'] as bool?,
);

Map<String, dynamic> _$ModelModelToJson(ModelModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'release_date': instance.releaseDate,
      'attachment': instance.attachment,
      'reasoning': instance.reasoning,
      'temperature': instance.temperature,
      'tool_call': instance.toolCall,
      'cost': instance.cost,
      'limit': instance.limit,
      'options': instance.options,
      'knowledge': instance.knowledge,
      'last_updated': instance.lastUpdated,
      'modalities': instance.modalities,
      'open_weights': instance.openWeights,
    };

ModelCostModel _$ModelCostModelFromJson(Map<String, dynamic> json) =>
    ModelCostModel(
      input: ModelCostModel._doubleFromJson(json['input']),
      output: ModelCostModel._doubleFromJson(json['output']),
      cacheRead: ModelCostModel._nullableDoubleFromJson(json['cache_read']),
      cacheWrite: ModelCostModel._nullableDoubleFromJson(json['cache_write']),
    );

Map<String, dynamic> _$ModelCostModelToJson(ModelCostModel instance) =>
    <String, dynamic>{
      'input': instance.input,
      'output': instance.output,
      'cache_read': instance.cacheRead,
      'cache_write': instance.cacheWrite,
    };

ModelLimitModel _$ModelLimitModelFromJson(Map<String, dynamic> json) =>
    ModelLimitModel(
      context: (json['context'] as num).toInt(),
      output: (json['output'] as num).toInt(),
    );

Map<String, dynamic> _$ModelLimitModelToJson(ModelLimitModel instance) =>
    <String, dynamic>{'context': instance.context, 'output': instance.output};
