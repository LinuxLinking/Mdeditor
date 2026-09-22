import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/mdeditor_logo.dart';
import 'theme_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final themeController = context.watch<ThemeController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('settings')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _BrandHeader(label: l.t('app_title')),
            const SizedBox(height: 20),

            // ---------- 外观 ----------
            _SectionCard(
              icon: Icons.palette_outlined,
              title: l.t('appearance'),
              description: l.t('theme_system_desc'),
              child: _FullWidthSegmentedButton<ThemeModePreference>(
                selected: themeController.mode,
                onSelectionChanged: themeController.setMode,
                segments: [
                  ButtonSegment(
                    value: ThemeModePreference.system,
                    icon: const Icon(Icons.brightness_auto, size: 18),
                    label: Text(l.t('theme_system')),
                  ),
                  ButtonSegment(
                    value: ThemeModePreference.light,
                    icon: const Icon(Icons.light_mode, size: 18),
                    label: Text(l.t('theme_light')),
                  ),
                  ButtonSegment(
                    value: ThemeModePreference.dark,
                    icon: const Icon(Icons.dark_mode, size: 18),
                    label: Text(l.t('theme_dark')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ---------- 编辑器主题 ----------
            _SectionCard(
              icon: Icons.brush_outlined,
              title: l.t('editor_theme'),
              description: l.t('editor_theme_desc'),
              child: DropdownButtonFormField<EditorThemePreference>(
                initialValue: themeController.editorTheme,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: [
                  DropdownMenuItem(
                    value: EditorThemePreference.githubLight,
                    child: Row(
                      children: [
                        _ThemeSwatch(
                          background: const Color(0xFFFFFFFF),
                          foreground: const Color(0xFF24292F),
                        ),
                        const SizedBox(width: 10),
                        Text(l.t('github_light')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: EditorThemePreference.githubDark,
                    child: Row(
                      children: [
                        _ThemeSwatch(
                          background: const Color(0xFF0D1117),
                          foreground: const Color(0xFFE6EDF3),
                        ),
                        const SizedBox(width: 10),
                        Text(l.t('github_dark')),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: EditorThemePreference.vue,
                    child: Row(
                      children: [
                        _ThemeSwatch(
                          background: const Color(0xFFF8FAF9),
                          foreground: const Color(0xFF42B883),
                        ),
                        const SizedBox(width: 10),
                        Text(l.t('vue_theme')),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) themeController.setEditorTheme(value);
                },
              ),
            ),

            const SizedBox(height: 14),

            // ---------- 字体 ----------
            _SectionCard(
              icon: Icons.format_size_outlined,
              title: l.t('font'),
              description: null,
              child: _FullWidthSegmentedButton<TextScalePreference>(
                selected: themeController.scale,
                onSelectionChanged: themeController.setScale,
                segments: [
                  ButtonSegment(
                    value: TextScalePreference.small,
                    label: Text(l.t('text_scale_small')),
                  ),
                  ButtonSegment(
                    value: TextScalePreference.standard,
                    label: Text(l.t('text_scale_standard')),
                  ),
                  ButtonSegment(
                    value: TextScalePreference.large,
                    label: Text(l.t('text_scale_large')),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ---------- 关于 ----------
            _SectionCard(
              icon: Icons.info_outline,
              title: l.t('about'),
              description: null,
              child: Row(
                children: [
                  MdeditorLogo(
                    size: 40,
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(9),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mdeditor',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.t('about_subtitle'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部品牌标识 —— Logo + 标题。
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          MdeditorLogo(
            size: 36,
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(9),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置分组卡片（图标 + 标题 + 描述 + 内容）。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// 全宽 SegmentedButton。
class _FullWidthSegmentedButton<T> extends StatelessWidget {
  const _FullWidthSegmentedButton({
    required this.selected,
    required this.onSelectionChanged,
    required this.segments,
  });

  final T selected;
  final ValueChanged<T> onSelectionChanged;
  final List<ButtonSegment<T>> segments;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        selected: {selected},
        segments: segments,
        onSelectionChanged: (values) => onSelectionChanged(values.single),
      ),
    );
  }
}

/// 主题色块（小圆角矩形 + 前景点）。
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 22,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: foreground, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
