import 'package:flutter/widgets.dart';

class VanMateWorkspaceConfig {
  final String workspaceId;
  final String displayName;
  final bool supportsFirmWorkspace;

  const VanMateWorkspaceConfig({
    required this.workspaceId,
    required this.displayName,
    required this.supportsFirmWorkspace,
  });

  const VanMateWorkspaceConfig.personal()
    : this(
        workspaceId: 'personal',
        displayName: 'Personal Workspace',
        supportsFirmWorkspace: false,
      );
}

class VanMateWorkspaceScope extends InheritedWidget {
  final VanMateWorkspaceConfig config;

  const VanMateWorkspaceScope({
    super.key,
    required this.config,
    required super.child,
  });

  static VanMateWorkspaceConfig of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<VanMateWorkspaceScope>();
    assert(scope != null, 'No VanMateWorkspaceScope found in context.');
    return scope!.config;
  }

  @override
  bool updateShouldNotify(VanMateWorkspaceScope oldWidget) {
    return config.workspaceId != oldWidget.config.workspaceId ||
        config.displayName != oldWidget.config.displayName ||
        config.supportsFirmWorkspace != oldWidget.config.supportsFirmWorkspace;
  }
}
