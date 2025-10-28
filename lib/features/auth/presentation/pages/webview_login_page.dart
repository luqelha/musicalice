import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:musicalice/core/services/spotify_auth_service.dart';

class WebViewLoginPage extends StatefulWidget {
  final SpotifyAuthService authService;
  final String loginUrl;

  const WebViewLoginPage({
    super.key,
    required this.authService,
    required this.loginUrl,
  });

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('🌐 Page started: $url');

            // Cek apakah URL redirect ke musicalice://callback
            if (url.startsWith('musicalice://callback')) {
              _handleCallback(url);
            }
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🔗 Navigation: ${request.url}');

            if (request.url.startsWith('musicalice://callback')) {
              _handleCallback(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  Future<void> _handleCallback(String url) async {
    debugPrint('✅ Callback received: $url');

    setState(() {
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(url);
      final success = await widget.authService.handleCallback(uri);

      if (mounted) {
        if (success) {
          // Login berhasil, kembali dengan result true
          Navigator.of(context).pop(true);
        } else {
          // Login gagal
          _showErrorDialog('Login failed. Please try again.');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling callback: $e');
      if (mounted) {
        _showErrorDialog('An error occurred: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, false);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Login to Spotify',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            ),
        ],
      ),
    );
  }
}
