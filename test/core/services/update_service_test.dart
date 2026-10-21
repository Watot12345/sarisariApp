import 'package:flutter_test/flutter_test.dart';
import 'package:tindahan/core/services/update_service.dart';

void main() {
  group('UpdateService Version Comparison', () {
    test('detects newer patch versions', () {
      expect(UpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.0.1', 'v1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.1+2', '1.0.0+1'), isTrue);
    });

    test('detects newer minor and major versions', () {
      expect(UpdateService.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('returns false when version is equal or older', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('v1.0.0', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('handles different number of semantic components', () {
      expect(UpdateService.isNewerVersion('1.0.0.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.1', '1.0.5'), isTrue);
      expect(UpdateService.isNewerVersion('1.0', '1.0.0'), isFalse);
    });
  });

  group('ReleaseInfo JSON Parsing', () {
    test('parses standard GitHub Release response and finds APK asset', () {
      final json = {
        'tag_name': 'v1.0.1',
        'name': 'SariMe v1.0.1 Update',
        'html_url': 'https://github.com/Watot12345/sarisariApp/releases/tag/v1.0.1',
        'body': '### What\'s New\n- Faster barcode scanning\n- Added sound effects',
        'published_at': '2026-10-21T12:00:00Z',
        'assets': [
          {
            'name': 'source-code.zip',
            'browser_download_url': 'https://github.com/Watot12345/sarisariApp/releases/download/v1.0.1/source.zip',
          },
          {
            'name': 'SariMe-v1.0.1.apk',
            'browser_download_url': 'https://github.com/Watot12345/sarisariApp/releases/download/v1.0.1/SariMe-v1.0.1.apk',
          },
        ],
      };

      final info = ReleaseInfo.fromJson(json);
      expect(info.tagName, equals('v1.0.1'));
      expect(info.version, equals('1.0.1'));
      expect(info.releaseName, equals('SariMe v1.0.1 Update'));
      expect(info.changelog, contains('Faster barcode scanning'));
      expect(info.downloadUrl, equals('https://github.com/Watot12345/sarisariApp/releases/download/v1.0.1/SariMe-v1.0.1.apk'));
      expect(info.publishedAt, isNotNull);
    });

    test('falls back to default APK download URL when no APK in assets list', () {
      final json = {
        'tag_name': 'v1.0.2',
        'name': 'SariMe v1.0.2',
        'html_url': 'https://github.com/Watot12345/sarisariApp/releases/tag/v1.0.2',
        'body': 'Bug fixes',
        'assets': [],
      };

      final info = ReleaseInfo.fromJson(json);
      expect(info.version, equals('1.0.2'));
      expect(info.downloadUrl, contains('latest/download/app-release.apk'));
    });

    test('parses RemoteAppStatus and RemoteAnnouncement from status.json', () {
      final statusJson = {
        'latest_version': '1.1.0',
        'min_required_version': '1.0.5',
        'force_update': true,
        'download_url': 'https://github.com/Watot12345/sarisariApp/releases/latest/download/app-release.apk',
        'maintenance_mode': true,
        'maintenance_title': 'Scheduled Maintenance',
        'maintenance_title_tl': 'Pansamantalang Maintenance',
        'maintenance_message': 'We are upgrading servers.',
        'maintenance_message_tl': 'Ina-upgrade ang system.',
        'announcement': {
          'id': 'ann-1',
          'active': true,
          'title': 'New Update!',
          'title_tl': 'Bagong Update!',
          'message': 'Enjoy new features.',
          'message_tl': 'Subukan ang mga bagong tampok.',
        },
      };

      final status = RemoteAppStatus.fromJson(statusJson);
      expect(status.latestVersion, equals('1.1.0'));
      expect(status.minRequiredVersion, equals('1.0.5'));
      expect(status.forceUpdate, isTrue);
      expect(status.maintenanceMode, isTrue);
      expect(status.maintenanceTitleTl, equals('Pansamantalang Maintenance'));
      expect(status.announcement, isNotNull);
      expect(status.announcement!.active, isTrue);
      expect(status.announcement!.titleTl, equals('Bagong Update!'));
    });
  });
}
