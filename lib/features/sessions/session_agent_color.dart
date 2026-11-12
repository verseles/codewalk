import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter/material.dart';

/// The default agent's color when its harness names none (#484): green.
const sessionDefaultAgentColor = Color(0xFF2E7D32);

/// The `plan` agent's color when its harness names none (#484): hot pink.
const sessionPlanAgentColor = Color(0xFFFF1493);

/// Every other agent without a color of its own takes one of these, chosen
/// by its id alone, so it keeps its color across screens, projects and
/// catalog changes.
const sessionAgentPalette = [
  Color(0xFF1E88E5),
  Color(0xFFF57C00),
  Color(0xFF8E24AA),
  Color(0xFF00897B),
  Color(0xFF3949AB),
  Color(0xFF6D4C41),
];

/// The color that stands for [agentId] among [agents]: the agent's own when
/// its harness names one, otherwise green for the default agent (a session
/// without an agent of its own, or `build`), hot pink for `plan`, and a
/// palette color for any other, from its id. The defaults belong to
/// CodeWalk, so every harness gets them.
Color sessionAgentColor(List<CatalogEntry> agents, String? agentId) {
  final own = agents.where((agent) => agent.id == agentId).firstOrNull?.color;
  if (own != null) {
    return Color(0xFF000000 | int.parse(own.substring(1), radix: 16));
  }
  if (agentId == null || agentId == 'build') return sessionDefaultAgentColor;
  if (agentId == 'plan') return sessionPlanAgentColor;
  final slot = agentId.codeUnits.fold(
    0,
    (sum, unit) => (sum * 31 + unit) & 0xFFFF,
  );
  return sessionAgentPalette[slot % sessionAgentPalette.length];
}

/// A wash of [agent] over [surface]: the agent stays recognizable without
/// drawing the eye (owner, beta.21).
Color sessionAgentWash(Color agent, Color surface) =>
    Color.alphaBlend(agent.withValues(alpha: 0.35), surface);

/// Black or white, whichever reads better on [background].
Color sessionAgentForeground(Color background) {
  final luminance = background.computeLuminance();
  final onWhite = 1.05 / (luminance + 0.05);
  final onBlack = (luminance + 0.05) / 0.05;
  return onBlack >= onWhite ? Colors.black : Colors.white;
}
