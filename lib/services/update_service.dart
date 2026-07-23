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

  static String? downloadedApkPath;

  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return '1.0.0';
    }
  }

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

        if (_isNewerVersion(tagName, currentVer)) {
          return GitHubReleaseInfo(
            version: tagName,
            releaseNotes: body,
            downloadUrl: downloadUrl,
            htmlUrl: htmlUrl,
          );
        }
      }
    } catch (_) {}
    return null;
  }

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

  /// APK letöltése nyilvános tárhelyre + intelligens telepítési fallback
  static Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    required Function(double progress) onProgress,
  }) async {
    try {
      // 1. Ha nem közvetlen APK URL, megnyitjuk a külső böngészőben
      if (!downloadUrl.endsWith('.apk') && !downloadUrl.contains('.apk')) {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 10;

      final response = await client.send(request);

      if (response.statusCode != 200) {
        final uri = Uri.parse(downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return false;
      }

      final contentLength = response.contentLength ?? 0;

      // Nyilvános letöltési mappába mentünk, hogy az Android Csomagtelepítő könnyen hozzáférjen
      Directory? storageDir;
      if (Platform.isAndroid) {
        storageDir = Directory('/storage/emulated/0/Download');
        if (!await storageDir.exists()) {
          storageDir = await getExternalStorageDirectory();
        }
      }
      storageDir ??= await getTemporaryDirectory();

      final filePath = '${storageDir.path}/MoneyBox_v_update.apk';
      downloadedApkPath = filePath;
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      int bytesDownloaded = 0;
      final sink = file.openWrite();
      DateTime lastUiUpdate = DateTime.now();

      await response.stream.listen((chunk) {
        bytesDownloaded += chunk.length;
        sink.add(chunk);

        final now = DateTime.now();
        if (contentLength > 0 && now.difference(lastUiUpdate).inMilliseconds > 80) {
          lastUiUpdate = now;
          onProgress(bytesDownloaded / contentLength);
        }
      }).asFuture();

      onProgress(1.0);
      await sink.flush();
      await sink.close();

      return await installDownloadedApk(fallbackUrl: downloadUrl);
    } catch (e) {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    }
  }

  static Future<bool> installDownloadedApk({String? fallbackUrl}) async {
    if (downloadedApkPath == null) return false;
    try {
      final file = File(downloadedApkPath!);
      if (!await file.exists()) return false;

      final result = await OpenFilex.open(
        downloadedApkPath!,
        type: 'application/vnd.android.package-archive',
      );

      // Ha az Android csomagtelepítő nem tudta megenyitni (pl. eltérő aláírási kulcs miatt),
      // felajánljuk a közvetlen letöltési linket
      if (result.type != ResultType.done && fallbackUrl != null) {
        final uri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      return result.type == ResultType.done;
    } catch (_) {
      if (fallbackUrl != null) {
        final uri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      return false;
    }
  }
}
