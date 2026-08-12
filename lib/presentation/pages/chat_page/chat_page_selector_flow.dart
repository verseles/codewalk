part of '../chat_page.dart';

extension _ChatPageSelectorFlow on _ChatPageState {
  Widget _buildProjectSelectorTitle({
    required bool isMobile,
    required bool isLargeDesktop,
  }) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, child) {
        final currentDirectoryFull = _directoryLabel(
          projectProvider.currentDirectory,
        );
        final currentDirectoryChip = isMobile
            ? _directoryBasename(currentDirectoryFull)
            : currentDirectoryFull;

        return Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: context.l10n.chatChooseDirectory,
            child: InkWell(
              onTap: () => unawaited(_openProjectSelectorDialog()),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                key: const ValueKey<String>('project_selector_button'),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 2 : 4,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible allows the text to shrink when the AppBar
                    // title area is narrow (e.g. medium breakpoint with
                    // the conversation pane taking 260dp).
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile
                              ? 100
                              : (isLargeDesktop ? 400 : 300),
                        ),
                        child: Text(
                          currentDirectoryChip,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    const Icon(Symbols.arrow_drop_down, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProjectSelectorDialog() async {
    if (!mounted) {
      return;
    }
    final view = View.of(context);
    final screenWidth = MediaQueryData.fromView(view).size.width;
    final isSmallScreen = WindowSizeClass.fromWidth(screenWidth).isCompact;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Consumer<ProjectProvider>(
          builder: (context, projectProvider, child) {
            final content = _buildProjectSelectorDialogContent(
              dialogContext: dialogContext,
              projectProvider: projectProvider,
              isSmallScreen: isSmallScreen,
            );
            if (isSmallScreen) {
              return Dialog.fullscreen(
                key: const ValueKey<String>(
                  'project_selector_dialog_fullscreen',
                ),
                child: content,
              );
            }
            return Dialog(
              key: const ValueKey<String>('project_selector_dialog_centered'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 760,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 720),
                  child: content,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjectSelectorDialogContent({
    required BuildContext dialogContext,
    required ProjectProvider projectProvider,
    required bool isSmallScreen,
  }) {
    final colorScheme = Theme.of(dialogContext).colorScheme;
    final currentProject = projectProvider.currentProject;
    final selectorActionInFlight = _isProjectSelectorActionInFlight;
    final currentDirectoryFull = _directoryLabel(
      projectProvider.currentDirectory,
    );

    return Material(
      key: const ValueKey<String>('project_selector_dialog_content'),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 16 : 20,
              isSmallScreen ? 12 : 16,
              isSmallScreen ? 8 : 12,
              8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.chatProjectContext2,
                    style: Theme.of(dialogContext).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Symbols.close),
                  tooltip: context.l10n.chatClose,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isSmallScreen ? 16 : 20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentProject == null
                      ? context.l10n.workspaceNoActiveContext
                      : context.l10n.workspaceCurrentDirectory(
                          currentDirectoryFull,
                        ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.chatSelectProjectBelow,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isSmallScreen ? 16 : 20, 4, 20, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: selectorActionInFlight
                      ? null
                      : () => unawaited(
                          _openCreateWorkspaceFromSelector(dialogContext),
                        ),
                  icon: const Icon(Symbols.add_box),
                  label: Text(context.l10n.chatOpenProjectFolder),
                ),
                if (!FeatureFlags.refreshlessRealtime)
                  FilledButton.tonalIcon(
                    onPressed: selectorActionInFlight
                        ? null
                        : () => unawaited(projectProvider.loadProjects()),
                    icon: const Icon(Symbols.refresh_rounded),
                    label: Text(context.l10n.chatRefreshProjects),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              children: [
                _buildSelectorSectionHeader(
                  dialogContext,
                  context.l10n.workspaceOpenProjects,
                ),
                for (final project in projectProvider.openProjects)
                  _buildOpenProjectTile(
                    dialogContext: dialogContext,
                    project: project,
                    selected: project.id == currentProject?.id,
                    onSwitch: selectorActionInFlight
                        ? null
                        : () => unawaited(
                            _switchProjectFromSelector(
                              dialogContext,
                              project.id,
                            ),
                          ),
                    onClose: selectorActionInFlight
                        ? null
                        : () =>
                              unawaited(_closeProjectFromSelector(project.id)),
                    closeEnabled:
                        projectProvider.openProjects.length > 1 ||
                        project.id != currentProject?.id,
                  ),
                if (projectProvider.closedProjects.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSelectorSectionHeader(
                    dialogContext,
                    context.l10n.workspaceClosedProjects,
                  ),
                  for (final project in projectProvider.closedProjects)
                    Builder(
                      builder: (_) {
                        final displayName = _projectDisplayLabel(project);
                        return ListTile(
                          dense: _useDenseListTiles(dialogContext),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          onTap: selectorActionInFlight
                              ? null
                              : () => unawaited(
                                  _reopenProjectFromSelector(
                                    dialogContext,
                                    project.id,
                                  ),
                                ),
                          leading: ProjectIcon(project: project, size: 20),
                          title: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _directoryLabel(project.path),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Symbols.delete_outline_rounded,
                                ),
                                tooltip: context.l10n
                                    .chatRemoveDisplayNameHistory(displayName),
                                onPressed: selectorActionInFlight
                                    ? null
                                    : () => unawaited(
                                        _archiveClosedProjectFromSelector(
                                          project.id,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
