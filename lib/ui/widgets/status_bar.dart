import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../editor/editor_controller.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.controller,
    required this.fileName,
    required this.lastSavedAt,
  });

  final EditorController controller;
  final String fileName;
  final DateTime? lastSavedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final content = controller.content;
        final lines = content.isEmpty ? 0 : content.split('\n').length;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            border: Border(top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            )),
          ),
          child: Row(
            children: [
              Text('${content.characters.length} 字符', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: AppSpacing.md),
              Text('$lines 行', style: Theme.of(context).textTheme.labelSmall),
              const Spacer(),
              Icon(
                controller.isDirty ? Icons.edit_note : Icons.check_circle_outline,
                size: AppIconSize.xs,
                color: controller.isDirty ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxs + 2),
              Text(controller.isDirty ? '自动保存中…' : '已保存', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        );
      },
    );
  }
}
