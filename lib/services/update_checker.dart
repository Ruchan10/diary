import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import 'settings.dart';

@immutable
class UpdateInfo {
  const UpdateInfo({required this.version, required this.notes, required this.page, this.download});

  final String version;
  final String notes;
  final Uri page;

  /// Direct link to the APK asset of the release, when there is one.
  final Uri? download;
}

enum UpdateStatus { upToDate, available, notConfigured, failed }

class UpdateResult {
  const UpdateResult(this.status, {this.info, this.error});

  final UpdateStatus status;
  final UpdateInfo? info;
  final String? error;
}

/// Checks GitHub Releases of [AppConfig.updateRepo] for a newer version.
class UpdateController extends ChangeNotifier {
  UpdateController(this.settings);

  final SettingsController settings;

  Future<String>? _version;
  UpdateInfo? available;
  bool checking = false;

  static bool get isConfigured => RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(AppConfig.updateRepo);

  /// Always the same future, so a FutureBuilder showing it doesn't flicker on rebuilds.
  Future<String> currentVersion() => _version ??= PackageInfo.fromPlatform().then((p) => p.version);

  /// Quiet daily check on launch; respects "skip this version".
  Future<void> autoCheck() async {
    if (!isConfigured || !settings.autoCheckUpdates) return;
    final last = settings.lastUpdateCheck;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return;
    final result = await check();
    if (result.status == UpdateStatus.available && result.info!.version == settings.skippedVersion) {
      available = null;
      notifyListeners();
    }
  }

  Future<UpdateResult> check() async {
    if (!isConfigured) return const UpdateResult(UpdateStatus.notConfigured);
    checking = true;
    notifyListeners();
    try {
      final current = await currentVersion();
      final response = await http
          .get(
            Uri.https('api.github.com', '/repos/${AppConfig.updateRepo}/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      settings.lastUpdateCheck = DateTime.now();
      if (response.statusCode == 404) return const UpdateResult(UpdateStatus.upToDate);
      if (response.statusCode != 200) {
        return UpdateResult(UpdateStatus.failed, error: 'GitHub answered ${response.statusCode}.');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String? ?? '').trim();
      final version = tag.startsWith(RegExp('[vV]')) ? tag.substring(1) : tag;
      if (!isNewer(version, current)) {
        available = null;
        return const UpdateResult(UpdateStatus.upToDate);
      }
      Uri? apk;
      for (final asset in (json['assets'] as List<dynamic>? ?? const [])) {
        final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apk = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
          break;
        }
      }
      final info = UpdateInfo(
        version: version,
        notes: (json['body'] as String? ?? '').trim(),
        page: Uri.parse(json['html_url'] as String? ?? 'https://github.com/${AppConfig.updateRepo}/releases'),
        download: apk,
      );
      available = info;
      return UpdateResult(UpdateStatus.available, info: info);
    } on TimeoutException {
      return const UpdateResult(UpdateStatus.failed, error: 'The update server took too long to answer.');
    } catch (e) {
      return const UpdateResult(UpdateStatus.failed, error: 'Couldn’t reach the update server. Are you online?');
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  void skip(UpdateInfo info) {
    settings.skippedVersion = info.version;
    available = null;
    notifyListeners();
  }

  /// Compares dotted version numbers: `1.10.0` is newer than `1.9.3`.
  static bool isNewer(String candidate, String current) {
    List<int> parts(String v) =>
        v.split(RegExp(r'[.+-]')).take(3).map((p) => int.tryParse(p) ?? 0).toList()
          ..addAll(List.filled(3, 0));
    final a = parts(candidate), b = parts(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}
