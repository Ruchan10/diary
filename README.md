# Inkling ✒️

*A little ink for every day.* A cosy, private daily diary for Android, built with Flutter.

## What it does

- **Inky, your ink-drop buddy.** Inky blinks, hops and shows your mood (nine expressions). It cheers you
  on as you write, cracks jokes when you tap it, and covers its eyes on the lock screen. *Settings →
  Fun stuff → Animated Inky* turns the motion off, and Android's "Remove animations" setting is respected.
- **Celebrations and a sticker book.** Confetti and cheers for finishing today's page and for streak
  milestones (3, 7, 14, 30… days). There are 16 collectible stickers, such as Night owl, Mood ring,
  Time traveller and Novelist. Celebrations can be turned off.
- **Playful notebook look.** Ruled paper with a red margin, handwritten questions (roll the dice for a
  new one), an ink-blot calendar with a pencil circle around today, tilted sticker stats, polaroid
  memories, and squishy buttons.
- **Asks about your day the moment it opens.** The first screen is "What happened today?" with the
  keyboard already up. If you come back after 30+ minutes away, it asks again. You can change this
  under *Settings → When Inkling opens*.
- **Calendar dashboard.** Every day you wrote gets a filled ink drop, and streaks are joined by a soft
  band. Tap any past day to read or edit it. Swipe or use the arrows to change month, or tap the month
  name to jump.
- **One page per day, always autosaved.** You can add an optional mood, see a word count, and choose
  from four writing fonts. Clearing a page deletes it.
- **Streaks, stats, search, and "On this day"** memories from earlier years.
- **Home-screen widget** (resizable). It shows this week's ink dots, your streak, and today's line.
  Tap a day to open it, or tap *Write* to start today's page. It stays correct after midnight even if
  the app isn't running.
- **Daily reminder** that is skipped automatically on days you've already written.
- **Privacy.** App lock (fingerprint, face or screen lock) and a private mode that hides the app in
  recents and blocks screenshots. Nothing leaves the phone unless you export it.
- **Backup.** Export a JSON backup (save to a folder or share), export a readable Markdown copy, and
  import with *merge (keep newest)*, *merge (keep both)* or *replace*.
- **Appearance.** Light, dark or auto theme, 7 accent colours, Material You wallpaper colours on
  Android 12+, text size, week start, and an *ink* or *mood-coloured* calendar.
- **Updates.** Shows the app version, a "What's new" page, and can check GitHub Releases for new
  versions (see below).
- **Launcher shortcuts.** Long-press the icon for *Write today* and *Search diary*.

## Run it

```bash
flutter pub get
flutter run                 # debug on a connected phone
flutter test                # unit + widget tests
flutter build apk --release # build/app/outputs/flutter-apk/app-release.apk
```

### Update checks

Inkling checks the latest **GitHub Release** of a repository you choose and offers the attached
`.apk`. Set the repository at build time:

```bash
flutter build apk --release --dart-define=INKLING_UPDATE_REPO=your-name/inkling
```

Tag releases as `v1.2.0` to match `version:` in `pubspec.yaml`, and attach the APK. Builds without
the define show the version and release notes, but don't check for updates.

> Release builds are currently signed with the debug key (see `android/app/build.gradle.kts`).
> Before sharing APKs, create your own keystore. Android only installs an update over an existing
> app if both are signed with the same key.

## Project layout

```
lib/
  main.dart, app.dart        bootstrap, providers, theme, launch routing, lifecycle
  navigation.dart            routes + widget/notification/shortcut deep links (inkling://…)
  data/                      DiaryEntry, SQLite repository, backup formats, changelog
  services/                  settings, reminders, app lock, widget sync, update checker
  screens/                   compose (writing), home (calendar), search, settings, lock
  widgets/                   calendar, entry tiles, mood picker, the ink-drop mascot
android/app/src/main/
  kotlin/.../InklingWidgetProvider.kt   home-screen widget (RemoteViews)
  kotlin/.../MainActivity.kt            FLAG_SECURE + notification-settings bridge
  res/layout/inkling_widget*.xml        widget layouts (they double as the picker preview)
```

Fonts (Fraunces, Lora, Caveat, Courier Prime) are bundled under the SIL Open Font License. Their
licences are listed in *Settings → About → View licenses*.
