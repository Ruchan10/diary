/// App-wide constants.
abstract final class AppConfig {
  static const appName = 'Inkling';
  static const tagline = 'A little ink for every day.';

  /// GitHub repository (`owner/name`) whose releases the update checker reads.
  /// Set it at build time, e.g.
  /// `flutter build apk --dart-define=INKLING_UPDATE_REPO=you/inkling`.
  /// When empty, update checks are switched off.
  static const updateRepo = String.fromEnvironment('INKLING_UPDATE_REPO');

  /// Fully qualified name of the Android home-screen widget provider.
  static const widgetProvider = 'com.inovaara.inkling.InklingWidgetProvider';
}
