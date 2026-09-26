import 'package:flutter/material.dart';

import '../../../theme/app_visual_style_tokens.dart';
import '../../../utils/window_size_class.dart';

export 'settings_search_navigation.dart';

class SettingsSurfaceTheme extends StatelessWidget {
  const SettingsSurfaceTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = theme.cardTheme.shape;
    final data = theme.visualStyleTokens.isRefined && shape is OutlinedBorder
        ? theme.copyWith(
            cardTheme: theme.cardTheme.copyWith(
              shape: shape.copyWith(side: BorderSide.none),
            ),
          )
        : theme;
    // Keep the same subtree when switching styles so form state survives.
    return Theme(data: data, child: child);
  }
}

class SettingsSectionIntro extends StatelessWidget {
  const SettingsSectionIntro({
    super.key,
    required this.title,
    required this.description,
    this.hideTitleOnCompact = false,
  });

  final String title;
  final String description;
  final bool hideTitleOnCompact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showTitle =
        !hideTitleOnCompact || context.windowSizeClass.isAtLeastExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
        ],
        Text(
          description,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class SettingsGroupHeader extends StatelessWidget {
  const SettingsGroupHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
