import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final GitHubReleaseInfo releaseInfo;

  const UpdateDialog({super.key, required this.releaseInfo});

  static Future<void> show(BuildContext context, GitHubReleaseInfo info) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateDialog(releaseInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _downloadFinished = false;

  void _startRealDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final success = await UpdateService.downloadAndInstallApk(
      downloadUrl: widget.releaseInfo.downloadUrl,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadFinished = true;
      });

      if (success) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsProvider.of(context);
    final mediaQuery = MediaQuery.of(context);

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: kBorder, width: 1.5),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, mediaQuery.padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: s.accentColor.withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(color: s.accentColor.withAlpha(80)),
                ),
                child: Icon(Icons.system_update_rounded, color: s.accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Új frissítés érhető el! 🎉',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: UpdateService.getCurrentVersion(),
                      builder: (context, snapshot) {
                        final currentVer = snapshot.data ?? '1.0.0';
                        return Text(
                          'Jelenlegi: v$currentVer  →  Új: v${widget.releaseInfo.version}',
                          style: TextStyle(color: s.accentColor, fontSize: 13, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: kBorder),
          const SizedBox(height: 14),

          // Release Notes Header
          Row(
            children: [
              const Icon(Icons.article_outlined, color: kDim2, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Újdonságok (Release Notes)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scrollable Markdown View from GitHub Release Body
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: widget.releaseInfo.releaseNotes.isEmpty
                      ? '_Nincs megadva részletes leírás ehhez a kiadáshoz._'
                      : widget.releaseInfo.releaseNotes,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    h1: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    h3: TextStyle(color: s.accentColor, fontSize: 14, fontWeight: FontWeight.bold),
                    listBullet: TextStyle(color: s.accentColor, fontSize: 14),
                    strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    em: const TextStyle(color: kDim2, fontStyle: FontStyle.italic),
                    code: const TextStyle(color: kGold, fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Background Auto-Download Switch Option
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: kSurface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.downloading_rounded, color: s.accentColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isDownloading
                            ? 'Letöltés folyamatban: ${(_downloadProgress * 100).toInt()}%'
                            : (_downloadFinished ? 'APK letöltve! Telepítésre kész' : 'Letöltés a háttérben'),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _isDownloading ? 'APK letöltése a GitHub-ról...' : 'Csendesletöltés indítása azonnal',
                        style: const TextStyle(color: kDim2, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isDownloading || _downloadFinished,
                  activeThumbColor: s.accentColor,
                  onChanged: (val) {
                    if (val && !_isDownloading && !_downloadFinished) {
                      _startRealDownload();
                    }
                  },
                ),
              ],
            ),
          ),

          if (_isDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: kSurface2,
              color: s.accentColor,
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Mégse', style: TextStyle(color: kDim2, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _downloadFinished ? kPos : s.accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isDownloading ? null : _startRealDownload,
                  icon: Icon(_downloadFinished ? Icons.install_mobile_rounded : Icons.download_rounded, size: 20),
                  label: Text(
                    _downloadFinished ? 'Telepítés' : 'Frissítés',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
