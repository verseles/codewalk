import 'package:flutter/material.dart';

import 'settings_page.dart';

class ServerSettingsPage extends StatelessWidget {
  const ServerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsPage(initialSectionId: 'servers');
  }
}
