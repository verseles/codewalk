import '../../domain/entities/agent.dart';

class AgentModel {
  const AgentModel({
    required this.name,
    required this.mode,
    required this.hidden,
    required this.native,
    this.color,
  });

  final String name;
  final String mode;
  final bool hidden;
  final bool native;
  final String? color;

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      name: json['name'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      hidden: json['hidden'] == true,
      native: json['native'] == true,
      color: json['color'] as String?,
    );
  }

  Agent toDomain() {
    return Agent(
      name: name,
      mode: mode,
      hidden: hidden,
      native: native,
      color: color,
    );
  }
}
