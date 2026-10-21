import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';

/// Details of a release fetched from GitHub Releases.
class ReleaseInfo {
  final String tagName;
  final String version;
  final String releaseName;
  final String htmlUrl;
  final String downloadUrl;
  final String changelog;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.releaseName,
    required this.htmlUrl,
    required this.downloadUrl,
    required this.changelog,
    this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final rawVersion = tagName.replaceFirst(RegExp(r'^[vV]'), '');
    final assets = json['assets'] as List<dynamic>? ?? [];

    // Find the first APK asset if present, or fallback to standard release URL
    String apkUrl = '';
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'] as String? ?? '';
        final download = asset['browser_download_url'] as String? ?? '';
        if (name.endsWith('.apk') && download.isNotEmpty) {
          apkUrl = download;
          break;
        }
      }
    }

    if (apkUrl.isEmpty) {
      apkUrl = AppConstants.latestApkDownloadUrl;
    }

    DateTime? pubDate;
    if (json['published_at'] != null) {
      try {
        pubDate = DateTime.parse(json['published_at'] as String);
      } catch (_) {}
    }

    return ReleaseInfo(
      tagName: tagName,
      version: rawVersion.isNotEmpty ? rawVersion : tagName,
      releaseName: json['name'] as String? ?? tagName,
      htmlUrl: json['html_url'] as String? ?? AppConstants.githubReleasesPageUrl,
      downloadUrl: apkUrl,
      changelog: json['body'] as String? ?? '',
      publishedAt: pubDate,
    );
  }
}

/// Remote announcement payload configured in docs/status.json.
class RemoteAnnouncement {
  final String id;
  final bool active;
  final String title;
  final String titleTl;
  final String message;
  final String messageTl;

  const RemoteAnnouncement({
    required this.id,
    required this.active,
    required this.title,
    required this.titleTl,
    required this.message,
    required this.messageTl,
  });

  factory RemoteAnnouncement.fromJson(Map<String, dynamic> json) {
    final enTitle = json['title'] as String? ?? 'Announcement';
    final enMsg = json['message'] as String? ?? '';
    return RemoteAnnouncement(
      id: json['id'] as String? ?? 'default',
      active: json['active'] as bool? ?? false,
      title: enTitle,
      titleTl: json['title_tl'] as String? ?? enTitle,
      message: enMsg,
      messageTl: json['message_tl'] as String? ?? enMsg,
    );
  }
}

/// Remote status configuration fetched from GitHub Pages (docs/status.json) or GitHub Releases.
class RemoteAppStatus {
  final String latestVersion;
  final String minRequiredVersion;
  final bool forceUpdate;
  final String downloadUrl;
  final bool maintenanceMode;
  final String maintenanceTitle;
  final String maintenanceTitleTl;
  final String maintenanceMessage;
  final String maintenanceMessageTl;
  final RemoteAnnouncement? announcement;

  const RemoteAppStatus({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.maintenanceMode,
    required this.maintenanceTitle,
    required this.maintenanceTitleTl,
    required this.maintenanceMessage,
    required this.maintenanceMessageTl,
    this.announcement,
  });

  factory RemoteAppStatus.fromJson(Map<String, dynamic> json) {
    final mTitle = json['maintenance_title'] as String? ?? 'Scheduled Maintenance';
    final mMsg = json['maintenance_message'] as String? ??
        'SariMe is temporarily undergoing maintenance. Your local store data is 100% safe.';
    final annJson = json['announcement'];
    return RemoteAppStatus(
      latestVersion: (json['latest_version'] as String? ?? AppConstants.appVersion)
          .replaceFirst(RegExp(r'^[vV]'), ''),
      minRequiredVersion: (json['min_required_version'] as String? ?? AppConstants.appVersion)
          .replaceFirst(RegExp(r'^[vV]'), ''),
      forceUpdate: json['force_update'] as bool? ?? false,
      downloadUrl: json['download_url'] as String? ?? AppConstants.latestApkDownloadUrl,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceTitle: mTitle,
      maintenanceTitleTl: json['maintenance_title_tl'] as String? ?? mTitle,
      maintenanceMessage: mMsg,
      maintenanceMessageTl: json['maintenance_message_tl'] as String? ?? mMsg,
      announcement: annJson is Map<String, dynamic>
          ? RemoteAnnouncement.fromJson(annJson)
          : null,
    );
  }
}

/// The result returned after checking for updates.
class UpdateCheckResult {
  final bool hasUpdate;
  final bool forceUpdate;
  final bool maintenanceMode;
  final ReleaseInfo? latestRelease;
  final RemoteAppStatus? remoteStatus;
  final String currentVersion;
  final String? errorMessage;
  final bool isOffline;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.forceUpdate = false,
    this.maintenanceMode = false,
    this.latestRelease,
    this.remoteStatus,
    this.errorMessage,
    this.isOffline = false,
  });
}

/// Service that handles checking GitHub Releases & GitHub Pages status.json
/// for new APK updates, announcements, and remote maintenance/shutdown mode.
class UpdateService {
  final HttpClient _client;

  UpdateService({HttpClient? client}) : _client = client ?? HttpClient();

  /// Compares [latest] version string with [current] version string.
  /// Returns true if [latest] is strictly newer than [current].
  static bool isNewerVersion(String latest, String current) {
    try {
      final cleanLatest = latest.replaceFirst(RegExp(r'^[vV]'), '').split('+').first.trim();
      final cleanCurrent = current.replaceFirst(RegExp(r'^[vV]'), '').split('+').first.trim();

      final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  /// Fetches remote app status (`docs/status.json`) from GitHub Pages if available.
  Future<RemoteAppStatus?> fetchRemoteStatus() async {
    try {
      final uri = Uri.parse(
        '${AppConstants.remoteStatusUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.headers.set('User-Agent', 'SariMe-App-StatusChecker');
      request.headers.set('Cache-Control', 'no-cache');
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return RemoteAppStatus.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// Checks both GitHub Pages `status.json` and GitHub Releases API for updates,
  /// announcements, force-update requirements, and maintenance/shutdown mode.
  Future<UpdateCheckResult> checkForUpdate({String? currentVersionOverride}) async {
    final current = currentVersionOverride ?? AppConstants.appVersion;

    RemoteAppStatus? remoteStatus;
    try {
      remoteStatus = await fetchRemoteStatus();
    } catch (_) {}

    try {
      final uri = Uri.parse(AppConstants.githubReleasesApiUrl);
      final request = await _client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.set('User-Agent', 'SariMe-App-UpdateChecker');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close().timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final release = ReleaseInfo.fromJson(json);

        final newerFromRelease = isNewerVersion(release.version, current);
        final newerFromStatus = remoteStatus != null &&
            isNewerVersion(remoteStatus.latestVersion, current);
        final belowMinRequired = remoteStatus != null &&
            isNewerVersion(remoteStatus.minRequiredVersion, current);

        final bodyUpper = release.changelog.toUpperCase();
        final releaseMaintenance =
            bodyUpper.contains('[MAINTENANCE]') || bodyUpper.contains('[SHUTDOWN]');
        final releaseForceUpdate = bodyUpper.contains('[FORCE_UPDATE]');

        return UpdateCheckResult(
          hasUpdate: newerFromRelease || newerFromStatus,
          forceUpdate: (remoteStatus?.forceUpdate ?? false) ||
              belowMinRequired ||
              releaseForceUpdate,
          maintenanceMode: (remoteStatus?.maintenanceMode ?? false) ||
              releaseMaintenance,
          latestRelease: release,
          remoteStatus: remoteStatus,
          currentVersion: current,
        );
      } else if (remoteStatus != null) {
        final newerFromStatus = isNewerVersion(remoteStatus.latestVersion, current);
        final belowMinRequired = isNewerVersion(remoteStatus.minRequiredVersion, current);
        return UpdateCheckResult(
          hasUpdate: newerFromStatus,
          forceUpdate: remoteStatus.forceUpdate || belowMinRequired,
          maintenanceMode: remoteStatus.maintenanceMode,
          remoteStatus: remoteStatus,
          latestRelease: ReleaseInfo(
            tagName: 'v${remoteStatus.latestVersion}',
            version: remoteStatus.latestVersion,
            releaseName: 'SariMe v${remoteStatus.latestVersion}',
            htmlUrl: AppConstants.githubReleasesPageUrl,
            downloadUrl: remoteStatus.downloadUrl,
            changelog: remoteStatus.announcement?.message ?? '',
          ),
          currentVersion: current,
        );
      } else if (response.statusCode == 404) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: current,
          errorMessage: 'No releases published yet on GitHub repository.',
        );
      } else {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: current,
          errorMessage: 'GitHub API responded with code: ${response.statusCode}',
        );
      }
    } on SocketException catch (_) {
      if (remoteStatus != null) {
        final newerFromStatus = isNewerVersion(remoteStatus.latestVersion, current);
        return UpdateCheckResult(
          hasUpdate: newerFromStatus,
          forceUpdate: remoteStatus.forceUpdate,
          maintenanceMode: remoteStatus.maintenanceMode,
          remoteStatus: remoteStatus,
          currentVersion: current,
        );
      }
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: current,
        isOffline: true,
        errorMessage: 'Unable to connect to GitHub. Check internet connection.',
      );
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: current,
        errorMessage: e.toString(),
      );
    }
  }

  /// Opens a URL in the user's default browser or external handler.
  static Future<bool> openUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching URL $urlString: $e');
      return false;
    }
  }

  /// Opens the direct APK download from GitHub Releases.
  static Future<bool> downloadLatestApk([String? customApkUrl]) async {
    final url = customApkUrl ?? AppConstants.latestApkDownloadUrl;
    return openUrl(url);
  }

  /// Opens the GitHub Pages Landing Page for SariMe.
  static Future<bool> openLandingPage() async {
    return openUrl(AppConstants.landingPageUrl);
  }

  /// Opens the GitHub Releases page.
  static Future<bool> openReleasesPage() async {
    return openUrl(AppConstants.githubReleasesPageUrl);
  }
}
