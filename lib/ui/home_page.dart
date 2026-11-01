import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../file_io/file_service.dart';
import '../file_io/recent_files.dart';
import '../file_io/saf_channel.dart';
import '../l10n/app_localizations.dart';
import '../utils/error_handler.dart';
import 'editor_page.dart';
import 'settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<RecentFile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRecentFiles();
    _ensureAllFilesAccess();
  }

  /// 引导授权"所有文件访问权限"(MANAGE_EXTERNAL_STORAGE)。
  /// 修 0B 空壳:Android 14 分区存储下 app 默认对 Download 公共目录无权限
  /// (run-as 实测 ls/rm 均 Permission denied),无法清理保存时 SAF provider
  /// 物化的 0B 空壳。授权后 deleteZeroSiblings 才能用 File 清理。
  /// 首次启动未授权时弹一次性引导对话框。
  Future<void> _ensureAllFilesAccess() async {
    final granted = await SafChannel.hasAllFilesAccess();
    if (granted || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAllFilesAccessDialog();
    });
  }

  void _showAllFilesAccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('清理空壳文件需要授权'),
        content: const Text(
          '保存 Markdown 时,系统可能在 Download 目录产生多余的 0B 空壳文件。'
          '为了自动清理这些空壳,需要授予"所有文件访问权限"。'
          '这是一次性授权,之后保存体验不变。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('以后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SafChannel.requestAllFilesAccess();
            },
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  Future<List<RecentFile>> _loadRecentFiles() {
    return context.read<RecentFiles>().all();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final future = _loadRecentFiles();
    // 修红屏:setState 回调不能返回 Future。之前写 `setState(() => _future = future)`,
    // 箭头函数返回了赋值表达式的值(future,一个 Future 对象),触发
    // "setState() callback argument returned a Future" 致命红屏。
    // 改用块函数体,返回 void。
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openViaSAF() async {
    try {
      final result = await FileService.instance.openViaSAF();
      if (result == null || !mounted) return;

      await context.read<RecentFiles>().add(
        RecentFile(
          uri: result.uri,
          name: result.name,
          lastOpened: DateTime.now(),
        ),
      );

      if (!mounted) return;
      await _pushEditor(result.uri, result.name);
      await _refresh();
    } catch (e, s) {
      if (!mounted) return;
      ErrorHandler.reportToUser(context, e, stack: s);
    }
  }

  Future<void> _newDoc() async {
    final l = AppLocalizations.of(context);
    await _pushEditor(null, l.t('untitled'));
    await _refresh();
  }

  Future<void> _openRecent(RecentFile file) async {
    await context.read<RecentFiles>().add(
      RecentFile(uri: file.uri, name: file.name, lastOpened: DateTime.now()),
    );
    if (!mounted) return;
    await _pushEditor(file.uri, file.name);
    await _refresh();
  }

  Future<void> _removeRecent(RecentFile file) async {
    await context.read<RecentFiles>().remove(file.uri);
    await _refresh();
  }

  Future<void> _pushEditor(Uri? uri, String name) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EditorPage(initialUri: uri, initialName: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('app_title')),
        actions: [
          IconButton(
            tooltip: l.t('new_doc'),
            icon: const Icon(Icons.note_add),
            onPressed: _newDoc,
          ),
          IconButton(
            tooltip: l.t('open'),
            icon: const Icon(Icons.folder_open),
            onPressed: _openViaSAF,
          ),
          IconButton(
            tooltip: l.t('settings'),
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<RecentFile>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _CenteredState(
                  icon: Icons.error_outline,
                  title: l.t('load_failed'),
                  body: snapshot.error.toString(),
                );
              }

              final files = snapshot.data ?? const [];
              if (files.isEmpty) {
                return _EmptyRecentState();
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: files.length + 1,
                separatorBuilder: (_, index) => index == 0
                    ? const SizedBox.shrink()
                    : const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        l.t('recent_files'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  final file = files[index - 1];
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      l.format('last_opened', {'time': _fmt(file.lastOpened)}),
                    ),
                    trailing: IconButton(
                      tooltip: l.t('remove_recent'),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeRecent(file),
                    ),
                    onTap: () => _openRecent(file),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime time) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} '
        '${pad(time.hour)}:${pad(time.minute)}';
  }
}

class _EmptyRecentState extends StatelessWidget {
  // 主操作入口(新建/打开)统一由 AppBar 提供,
  // 空态只做引导展示,不再重复按钮。
  const _EmptyRecentState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        _CenteredState(
          icon: Icons.description_outlined,
          title: l.t('no_recent_title'),
          body: l.t('no_recent_body'),
        ),

      ],
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
