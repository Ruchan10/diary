class ChangelogRelease {
  const ChangelogRelease(this.version, this.date, this.notes);

  final String version;
  final String date;
  final List<String> notes;
}

/// Newest first. Shown under Settings → What's new.
const changelog = [
  ChangelogRelease('1.1.0', 'October 2026', [
    'Meet Inky! Your ink-drop buddy blinks, hops, reacts to your mood and chats in speech bubbles 💧',
    'Celebrations: confetti and cheers for finished pages and streak milestones 🎉',
    'Sticker book: 16 stickers to collect, from Night owl to Novelist 🏆',
    'Notebook paper, handwritten questions and a dice to roll a new one 🎲',
    'Ink-blot calendar with a pencil circle for today',
    'Squishy buttons, tilted sticker stats and “On this day” polaroids',
    'Fun stuff settings to tone the animations down any time',
  ]),
  ChangelogRelease('1.0.0', 'October 2026', [
    'Hello, Inkling! ✨',
    'Opens straight to “What happened today?” with the keyboard ready',
    'Calendar with an ink drop on every day you wrote',
    'Moods, streaks, search and “On this day” memories',
    'Home-screen widget with your week at a glance',
    'Daily reminders that skip the days you already wrote',
    'App lock, private mode, JSON backups, Markdown export and import',
  ]),
];
