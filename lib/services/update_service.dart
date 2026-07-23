import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GitHubReleaseInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String htmlUrl;

  GitHubReleaseInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.htmlUrl,
  });
}

class UpdateService {
  static const String repoOwner = 'molnarkaroly210';
  static const String repoName = 'MoneyBox';

  static const String _apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Kiolvassa az aktuális verziót a pubspec.yaml fájlból
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Ellenőrzi a GitHub API-n, hogy van-e újabb release a jelenlegi verziónál
  static Future<GitHubReleaseInfo?> checkForUpdates() async {
    try {
      final currentVer = await getCurrentVersion();
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        final String tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '').trim();
        final String body = data['body'] ?? 'Nincs megadva újdonság leírás.';
        final String htmlUrl = data['html_url'] ?? 'https://github.com/$repoOwner/$repoName/releases';

        String downloadUrl = htmlUrl;
        if (data['assets'] != null && (data['assets'] as List).isNotEmpty) {
          final assets = data['assets'] as List;
          final apkAsset = assets.firstWhere(
            (a) => a['name'].toString().endsWith('.apk'),
            orElse: () => assets.first,
          );
          downloadUrl = apkAsset['browser_download_url'] ?? htmlUrl;
        }

        // Összehasonlítjuk a verziókat (csak ha a legújabb nagyobb a jelenleginél)
        if (_isNewerVersion(tagName, currentVer)) {
          return GitHubReleaseInfo(
            version: tagName,
            releaseNotes: body,
            downloadUrl: downloadUrl,
            htmlUrl: htmlUrl,
          );
        }
      }
    } catch (_) {
      // Offline vagy hálózati hiba
    }
    return null;
  }

  /// Verzió összehasonlító (pl. 1.0.1 > 1.0.0)
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return latest != current;
    }
  }

  /// Valódi APK letöltés háttérben streamelve és telepítő indítása
  static Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    try {
      // Ha nem közvetlen APK fájlra mutat (pl. weblap), megnyitjuk külső böngészőben
      if (!downloadUrl.endsWith('.apk')) {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) return false;

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/moneybox_update.apk';
      final file = File(filePath);

      int bytesDownloaded = 0;
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        bytesDownloaded += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          onProgress(bytesDownloaded / contentLength);
        }
      });

      await sink.flush();
      await sink.close();

      // Automatikus telepítés elindítása
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      return result.type == ResultType.done;
    } catch (e) {
      // Fallback: Ha elakad a letöltés vagy a fájl megnyitás, megnyitjuk a GitHub-ot
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    }
  }
}
