import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/backup.dart';
import '../data/changelog.dart';
import '../data/entry_repository.dart';
import '../data/stickers.dart';
import '../services/app_lock.dart';
import '../services/celebrations.dart';
import '../services/platform_bridge.dart';
import '../services/reminders.dart';
import '../services/settings.dart';
import '../services/update_checker.dart';
import '../theme/theme.dart';
import '../utils/dates.dart';
import '../widgets/inkling_logo.dart';
import 'stickers_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<SettingsController>();
    final repo = context.watch<EntryRepository>();
    final updates = context.watch<UpdateController>();
    final dynamicSeed = context.watch<DynamicSeed>().color;
    final material24h = MediaQuery.alwaysUse24HourFormatOf(context);
    final reminderTime = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(settings.reminderTime, alwaysUse24HourFormat: material24h);
    final lastBackup = settings.lastBackupAt;
    final stickersGot = unlockedStickers(StickerProgress.of(repo, today())).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Appearance ──────────────────────────────────────────────
          const _Header('Appearance', emoji: '🎨'),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.themeMode = s.first,
            ),
          ),
          if (dynamicSeed != null)
            SwitchListTile(
              secondary: const Icon(Icons.wallpaper_rounded),
              title: const Text('Wallpaper colours'),
              subtitle: const Text('Match Android’s Material You palette'),
              value: settings.dynamicColor,
              onChanged: (v) => settings.dynamicColor = v,
            ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Accent colour'),
            subtitle: Text(
              settings.dynamicColor && dynamicSeed != null
                  ? 'From your wallpaper'
                  : accents[settings.accent.clamp(0, accents.length - 1)].name,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 24, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, accent) in accents.indexed)
                  _AccentDot(
                    accent: accent,
                    selected: i == settings.accent && !(settings.dynamicColor && dynamicSeed != null),
                    onTap: () {
                      settings.accent = i;
                      if (settings.dynamicColor) settings.dynamicColor = false;
                    },
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text('Writing font'),
            subtitle: Text(settings.writingFont.label),
            onTap: () async {
              final font = await _chooseFont(context, settings.writingFont, settings.fontSize);
              if (font != null) settings.writingFont = font;
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_size_rounded),
            title: const Text('Text size'),
            subtitle: Slider(
              value: settings.fontSize,
              min: 14,
              max: 26,
              divisions: 6,
              label: settings.fontSize.round().toString(),
              onChanged: (v) => settings.fontSize = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 24, 8),
            child: Text(
              'Dear diary, today I…',
              style: writingStyle(settings.writingFont, settings.fontSize).copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendar colours'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<CalendarStyle>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: CalendarStyle.ink, label: Text('Ink')),
                  ButtonSegment(value: CalendarStyle.mood, label: Text('Mood colours')),
                ],
                selected: {settings.calendarStyle},
                onSelectionChanged: (s) => settings.calendarStyle = s.first,
              ),
            ),
          ),

          // ── Fun stuff ───────────────────────────────────────────────
          const _Header('Fun stuff', emoji: '🎉'),
          SwitchListTile(
            secondary: const Icon(Icons.celebration_outlined),
            title: const Text('Celebrations'),
            subtitle: const Text('Confetti and cheers for finished pages, streaks and stickers'),
            value: settings.celebrations,
            onChanged: (v) => settings.celebrations = v,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.animation_rounded),
            title: const Text('Animated Inky'),
            subtitle: const Text('Inky blinks, bobs and hops. Off for a calmer look'),
            value: settings.animatedInky,
            onChanged: (v) => settings.animatedInky = v,
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Sticker book'),
            subtitle: Text('$stickersGot of ${stickers.length} stickers collected'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StickersScreen())),
          ),

          // ── Writing ─────────────────────────────────────────────────
          const _Header('Writing', emoji: '✍️'),
          ListTile(
            leading: const Icon(Icons.launch_rounded),
            title: const Text('When Inkling opens'),
            subtitle: Text(settings.launchBehavior.label),
            onTap: () async {
              final v = await _choose(
                context,
                title: 'When Inkling opens',
                current: settings.launchBehavior,
                options: [for (final b in LaunchBehavior.values) (b, b.label, b.description)],
              );
              if (v != null) settings.launchBehavior = v;
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.celebration_outlined),
            title: const Text('Playful prompts'),
            subtitle: const Text('A different question each day'),
            value: settings.playfulPrompts,
            onChanged: (v) => settings.playfulPrompts = v,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.numbers_rounded),
            title: const Text('Word count'),
            subtitle: const Text('Show it while you write'),
            value: settings.showWordCount,
            onChanged: (v) => settings.showWordCount = v,
          ),
          ListTile(
            leading: const Icon(Icons.view_week_outlined),
            title: const Text('Week starts on'),
            subtitle: Text(_weekdayName(settings.weekStart, settings.firstWeekday)),
            onTap: () async {
              final v = await _choose(
                context,
                title: 'Week starts on',
                current: settings.weekStart,
                options: [
                  (0, 'Automatic', 'Follow your phone’s region'),
                  (DateTime.monday, 'Monday', null),
                  (DateTime.saturday, 'Saturday', null),
                  (DateTime.sunday, 'Sunday', null),
                ],
              );
              if (v != null) settings.weekStart = v;
            },
          ),

          // ── Reminders ───────────────────────────────────────────────
          const _Header('Reminders', emoji: '⏰'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Daily reminder'),
            subtitle: Text(
              settings.reminderEnabled
                  ? 'Every day at $reminderTime, skipped once you’ve written'
                  : 'A gentle nudge if you haven’t written yet',
            ),
            value: settings.reminderEnabled,
            onChanged: (on) => _toggleReminder(context, on),
          ),
          ListTile(
            enabled: settings.reminderEnabled,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Reminder time'),
            subtitle: Text(reminderTime),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: settings.reminderTime,
                helpText: 'Remind me at',
              );
              if (picked != null) settings.reminderTime = picked;
            },
          ),

          // ── Privacy ─────────────────────────────────────────────────
          const _Header('Privacy & security', emoji: '🔒'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded),
            title: const Text('App lock'),
            subtitle: const Text('Fingerprint, face or screen lock to open'),
            value: settings.appLock,
            onChanged: (on) async {
              final lock = context.read<AppLockController>();
              final ok = await lock.setEnabled(on);
              if (!ok && lock.lastError != null && context.mounted) _snack(context, lock.lastError!);
            },
          ),
          ListTile(
            enabled: settings.appLock,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Lock after'),
            subtitle: Text(_lockDelayLabel(settings.lockDelaySeconds)),
            onTap: () async {
              final v = await _choose(
                context,
                title: 'Lock after leaving the app',
                current: settings.lockDelaySeconds,
                options: [for (final s in const [0, 30, 60, 300, 900]) (s, _lockDelayLabel(s), null)],
              );
              if (v != null) settings.lockDelaySeconds = v;
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Private mode'),
            subtitle: const Text('Hide pages in recent apps and block screenshots'),
            value: settings.secureScreen,
            onChanged: (v) => settings.secureScreen = v,
          ),

          // ── Widget ──────────────────────────────────────────────────
          const _Header('Home screen', emoji: '🏠'),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Add the Inkling widget'),
            subtitle: const Text('Your week, your streak and a quick way to write'),
            onTap: () => _pinWidget(context),
          ),

          // ── Data ────────────────────────────────────────────────────
          const _Header('Backup & data', emoji: '💾'),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Export backup'),
            subtitle: Text(
              lastBackup == null ? 'Never backed up · JSON file you can import later' : 'Last backup ${timeAgo(lastBackup)}',
            ),
            onTap: () => _export(context, markdown: false),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Export as text'),
            subtitle: const Text('A readable Markdown copy of every page'),
            onTap: () => _export(context, markdown: true),
          ),
          ListTile(
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('Import backup'),
            subtitle: const Text('Restore or merge an Inkling backup'),
            onTap: () => _import(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text('Delete everything', style: TextStyle(color: scheme.error)),
            subtitle: Text('${repo.count} ${repo.count == 1 ? 'entry' : 'entries'} on this phone'),
            onTap: repo.isEmpty ? null : () => _deleteAll(context),
          ),

          // ── Updates ─────────────────────────────────────────────────
          const _Header('Updates', emoji: '✨'),
          FutureBuilder<String>(
            future: updates.currentVersion(),
            builder: (context, snap) => ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('Check for updates'),
              subtitle: Text(
                [
                  if (snap.hasData) 'Version ${snap.data}',
                  if (updates.available != null) '${updates.available!.version} available',
                  if (settings.lastUpdateCheck case final at?) 'checked ${timeAgo(at)}',
                ].join(' · '),
              ),
              trailing: updates.checking
                  ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : null,
              onTap: updates.checking ? null : () => _checkForUpdates(context),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.update_rounded),
            title: const Text('Check automatically'),
            subtitle: Text(UpdateController.isConfigured ? 'Once a day, when the app opens' : 'No update channel in this build'),
            value: settings.autoCheckUpdates && UpdateController.isConfigured,
            onChanged: UpdateController.isConfigured ? (v) => settings.autoCheckUpdates = v : null,
          ),
          ListTile(
            leading: const Icon(Icons.new_releases_outlined),
            title: const Text('What’s new'),
            subtitle: const Text('Release notes'),
            onTap: () => _showChangelog(context),
          ),

          // ── About ───────────────────────────────────────────────────
          const _Header('About', emoji: '💧'),
          ListTile(
            leading: const InklingLogo(size: 26),
            title: const Text('About Inkling'),
            subtitle: const Text(AppConfig.tagline),
            onTap: () async {
              final version = await updates.currentVersion();
              if (!context.mounted) return;
              showAboutDialog(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: version,
                applicationIcon: const InklingLogo(size: 56),
                applicationLegalese: 'Your entries never leave this phone unless you export them.',
              );
            },
          ),
        ],
      ),
    );
  }

  static String _weekdayName(int weekStart, int resolved) {
    const names = {1: 'Monday', 6: 'Saturday', 7: 'Sunday'};
    final name = names[resolved] ?? 'Monday';
    return weekStart == 0 ? 'Automatic ($name)' : name;
  }

  static String _lockDelayLabel(int seconds) => switch (seconds) {
    0 => 'Immediately',
    < 60 => 'After $seconds seconds',
    60 => 'After 1 minute',
    _ => 'After ${seconds ~/ 60} minutes',
  };

  Future<void> _toggleReminder(BuildContext context, bool on) async {
    final settings = context.read<SettingsController>();
    if (on) {
      final reminders = context.read<ReminderService>();
      final granted = await reminders.requestPermission() || await reminders.notificationsAllowed();
      if (!granted) {
        if (context.mounted) {
          _snack(
            context,
            'Notifications are turned off for Inkling.',
            action: SnackBarAction(label: 'Settings', onPressed: PlatformBridge.openNotificationSettings),
          );
        }
        return;
      }
    }
    settings.reminderEnabled = on;
    if (on && context.mounted) {
      final time = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(settings.reminderTime, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
      _snack(context, 'Reminder set for $time. Inky will nudge you ✨');
    }
  }

  Future<void> _pinWidget(BuildContext context) async {
    var pinned = false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() ?? false) {
        await HomeWidget.requestPinWidget(qualifiedAndroidName: AppConfig.widgetProvider);
        pinned = true;
      }
    } catch (_) {}
    if (pinned || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.widgets_outlined),
        title: const Text('Add the widget'),
        content: const Text('Long-press an empty spot on your home screen, tap “Widgets”, then find Inkling.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
      ),
    );
  }

  Future<void> _export(BuildContext context, {required bool markdown}) async {
    final repo = context.read<EntryRepository>();
    final settings = context.read<SettingsController>();
    final lock = context.read<AppLockController>();
    final updates = context.read<UpdateController>();
    if (repo.isEmpty) {
      _snack(context, 'Nothing to export yet. Write your first page!');
      return;
    }
    final share = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(markdown ? 'Export as text' : 'Export backup', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Save to a folder'),
              subtitle: const Text('Downloads, Drive or anywhere on your phone'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share…'),
              subtitle: const Text('Send it to another app'),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (share == null) return;

    final now = DateTime.now();
    final content = markdown
        ? Backup.encodeMarkdown(repo.allEntries, exportedAt: now)
        : Backup.encodeJson(repo.allEntries, exportedAt: now, appVersion: await updates.currentVersion());
    final bytes = utf8.encode(content);
    final name = Backup.fileName(now, markdown ? 'md' : 'json');
    final mime = markdown ? 'text/markdown' : 'application/json';

    try {
      var done = false;
      if (share) {
        final dir = await getTemporaryDirectory();
        final file = File(p.join(dir.path, name));
        await file.writeAsBytes(bytes, flush: true);
        final result = await lock.suspendWhile(
          () => SharePlus.instance.share(
            ShareParams(files: [XFile(file.path, mimeType: mime)], subject: 'My Inkling diary', title: name),
          ),
        );
        done = result.status != ShareResultStatus.dismissed;
      } else {
        final uri = await lock.suspendWhile(() => FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mime));
        done = uri != null;
      }
      if (!done) return;
      if (!markdown) settings.lastBackupAt = now;
      if (context.mounted) {
        _snack(context, '${repo.count} ${repo.count == 1 ? 'entry' : 'entries'} exported ✓');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Export failed: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final repo = context.read<EntryRepository>();
    final lock = context.read<AppLockController>();
    final PlatformFile? file;
    try {
      file = await lock.suspendWhile(() => FilePicker.pickFile(dialogTitle: 'Choose an Inkling backup'));
    } catch (e) {
      if (context.mounted) _snack(context, 'Couldn’t open the file picker: $e');
      return;
    }
    if (file == null || !context.mounted) return;

    final BackupContents contents;
    try {
      contents = Backup.decodeJson(utf8.decode(await file.readAsBytes(), allowMalformed: true));
    } on BackupFormatException catch (e) {
      if (context.mounted) _alert(context, 'Can’t import that file', e.message);
      return;
    } catch (e) {
      if (context.mounted) _alert(context, 'Can’t import that file', 'It couldn’t be read ($e).');
      return;
    }
    if (!context.mounted) return;

    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (_) => _ImportDialog(contents: contents, conflicts: repo.countConflicts(contents.entries), existing: repo.count),
    );
    if (mode == null || !context.mounted) return;
    if (mode == ImportMode.replaceAll && !repo.isEmpty) {
      final sure = await _confirm(
        context,
        title: 'Replace your whole diary?',
        message: 'All ${repo.count} pages on this phone will be replaced by the ${contents.entries.length} in the backup.',
        action: 'Replace',
      );
      if (!sure || !context.mounted) return;
    }
    try {
      final s = await repo.importEntries(contents.entries, mode);
      if (!context.mounted) return;
      context.read<Celebrations>().checkStickers(repo);
      _snack(
        context,
        s.changed == 0
            ? 'Already up to date, nothing new in that backup.'
            : 'Imported ✓ ${s.added} new${s.updated + s.merged > 0 ? ', ${s.updated + s.merged} updated' : ''}',
      );
    } catch (e) {
      if (context.mounted) _alert(context, 'Import failed', '$e');
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final repo = context.read<EntryRepository>();
    final sure = await _confirm(
      context,
      title: 'Delete your whole diary?',
      message:
          'All ${repo.count} pages will be permanently removed from this phone. '
          'Export a backup first if you might want them back.',
      action: 'Delete everything',
    );
    if (!sure) return;
    await repo.deleteAll();
    if (context.mounted) _snack(context, 'Diary cleared. A fresh notebook awaits.');
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final updates = context.read<UpdateController>();
    final result = await updates.check();
    final version = await updates.currentVersion();
    if (!context.mounted) return;
    switch (result.status) {
      case UpdateStatus.notConfigured:
        _alert(
          context,
          'Updates',
          'This build of Inkling isn’t linked to an update channel, so it can’t look for new versions. '
              'You’re on version $version.',
        );
      case UpdateStatus.upToDate:
        _snack(context, 'You’re on the latest version 🎉');
      case UpdateStatus.failed:
        _snack(context, result.error ?? 'Couldn’t check for updates.');
      case UpdateStatus.available:
        final info = result.info!;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.auto_awesome_rounded),
            title: Text('Inkling ${info.version} is available'),
            content: SingleChildScrollView(child: Text(info.notes.isEmpty ? 'A fresh version is ready.' : info.notes)),
            actions: [
              TextButton(
                onPressed: () {
                  updates.skip(info);
                  Navigator.pop(context);
                },
                child: const Text('Skip this one'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  launchUrl(info.download ?? info.page, mode: LaunchMode.externalApplication);
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
    }
  }

  void _showChangelog(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text('What’s new', style: theme.textTheme.headlineSmall),
            for (final release in changelog) ...[
              const SizedBox(height: 18),
              Text('Version ${release.version}', style: theme.textTheme.titleMedium),
              Text(release.date, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              for (final note in release.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: theme.textTheme.bodyMedium),
                      Expanded(child: Text(note, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────

void _snack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

Future<void> _alert(BuildContext context, String title, String message) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
  ),
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<T?> _choose<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String, String?)> options,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (value, label, description) in options)
          ListTile(
            title: Text(label),
            subtitle: description == null ? null : Text(description),
            trailing: value == current ? Icon(Icons.check_rounded, color: scheme.primary) : null,
            onTap: () => Navigator.pop(context, value),
          ),
      ],
    ),
  );
}

Future<WritingFont?> _chooseFont(BuildContext context, WritingFont current, double size) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<WritingFont>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Writing font'),
      children: [
        for (final font in WritingFont.values)
          ListTile(
            title: Text(font.label),
            subtitle: Text('Dear diary, today I…', style: writingStyle(font, size.clamp(14, 20))),
            trailing: font == current ? Icon(Icons.check_rounded, color: scheme.primary) : null,
            onTap: () => Navigator.pop(context, font),
          ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text, {required this.emoji});

  final String text;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 24, 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: handStyle(25, color: scheme.primary))),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.accent, required this.selected, required this.onTap});

  final Accent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: accent.name,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${accent.name} accent',
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 2),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent.color),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.contents, required this.conflicts, required this.existing});

  final BackupContents contents;
  final int conflicts;
  final int existing;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  ImportMode _mode = ImportMode.keepNewest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = widget.contents;
    final n = c.entries.length;
    final range = c.firstDay == null
        ? ''
        : isSameDay(c.firstDay!, c.lastDay!)
        ? ' from ${formatLong(c.firstDay!)}'
        : ' from ${formatShort(c.firstDay!)} to ${formatShort(c.lastDay!)}';
    final options = [
      (ImportMode.keepNewest, 'Merge, keep the newest', 'For days on both sides, keep whichever was edited last'),
      (ImportMode.keepBoth, 'Merge, keep both', 'Add the imported text below what’s already there'),
      if (widget.existing > 0)
        (ImportMode.replaceAll, 'Replace everything', 'Use only the backup; pages not in it are removed'),
    ];

    return AlertDialog(
      icon: const Icon(Icons.file_open_outlined),
      title: Text('Import $n ${n == 1 ? 'page' : 'pages'}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found $n ${n == 1 ? 'entry' : 'entries'}$range.'
              '${c.skipped > 0 ? ' ${c.skipped} unreadable records will be skipped.' : ''}'
              '${widget.conflicts > 0 ? '\n\n${widget.conflicts} of those days already have writing here.' : ''}',
            ),
            if (widget.conflicts > 0 || widget.existing > 0) ...[
              const SizedBox(height: 12),
              for (final (mode, label, description) in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  subtitle: Text(description),
                  leading: Icon(
                    _mode == mode ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                    color: _mode == mode ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                  onTap: () => setState(() => _mode = mode),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _mode), child: const Text('Import')),
      ],
    );
  }
}
