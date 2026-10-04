import 'package:flutter/widgets.dart';

import 'generated/v2_localizations.dart';

extension V2L10nContext on BuildContext {
  /// Keeps reusable widgets usable when mounted without the app delegates.
  V2Localizations get v2L10n =>
      Localizations.of<V2Localizations>(this, V2Localizations) ??
      lookupV2Localizations(const Locale('en'));
}
