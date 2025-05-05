import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

// Import for WebView widgets
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class MjpegView extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;

  const MjpegView({
    super.key,
    required this.streamUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    // Create platform-specific controller
    late final PlatformWebViewControllerCreationParams params;
    
    // Configure for WKWebView on iOS/macOS
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    // Create the WebViewController
    _controller = WebViewController.fromPlatformCreationParams(params);
    
    // Configure common settings
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _error = 'Failed to load stream: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
      );

    // Platform specific configurations
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    try {
      // For web platform, we need to use an iframe to properly handle the MJPEG stream
      if (kIsWeb) {
        _controller.loadHtmlString('''
          <!DOCTYPE html>
          <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
              img { width: 100%; height: 100%; object-fit: cover; }
            </style>
          </head>
          <body>
            <img src="${widget.streamUrl}" />
          </body>
          </html>
        ''');
      } else {
        // For desktop/mobile, use the direct URL
        _controller.loadRequest(Uri.parse(widget.streamUrl));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize WebView: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    try {
      _controller.clearCache();
    } catch (e) {
      // Ignore errors during dispose
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _initializeWebView();
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return WebViewWidget(
      controller: _controller,
      // Ensure proper sizing on all platforms
      layoutDirection: TextDirection.ltr,
      key: GlobalKey(),
    );
  }
}
