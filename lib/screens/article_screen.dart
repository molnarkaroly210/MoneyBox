import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart'; // import theme

class ArticleScreen extends StatefulWidget {
  final String url;
  final String title;

  const ArticleScreen({super.key, required this.url, required this.title});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  WebViewController? _controller;
  double _progress = 0;
  bool _isWebViewSupported = false;

  @override
  void initState() {
    super.initState();
    
    // Ellenőrizzük, hogy támogatott-e a WebView (kizárólag Android és iOS)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _isWebViewSupported = true;
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(kBg)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _progress = progress / 100.0;
                });
              }
            },
            onPageStarted: (String url) {},
            onPageFinished: (String url) {},
            onWebResourceError: (WebResourceError error) {},
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  Future<void> _launchExternal() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isWebViewSupported)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _controller?.reload(),
              tooltip: 'Frissítés',
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            onPressed: _launchExternal,
            tooltip: 'Megnyitás külső böngészőben',
          ),
        ],
        bottom: _isWebViewSupported && _progress < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: kSurface2,
                  color: kAccent,
                  minHeight: 2,
                ),
              )
            : const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, thickness: 1, color: kBorder),
              ),
      ),
      body: _isWebViewSupported
          ? WebViewWidget(controller: _controller!)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.desktop_windows_outlined, size: 64, color: kDim2),
                    const SizedBox(height: 24),
                    const Text(
                      'A beépített böngésző csak mobil (Android/iOS) platformon érhető el.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _launchExternal,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Megnyitás böngészőben'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: kBg,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
